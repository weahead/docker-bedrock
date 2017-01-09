#!/usr/bin/execlineb -P

with-contenv

foreground {

  backtick -i -n PKGS {
    find /var/www/html/web/app/themes -mindepth 2 -maxdepth 2 -name "package.json"
  }
  importas -u PKGS PKGS

  backtick -n LINES {
    pipeline {
      s6-echo -- ${PKGS}
    }
    grep -c .
  }
  importas -u LINES LINES

  ifelse { s6-test ${LINES} -eq 0 }
  {
    s6-echo -- "No package.json found, skipping Node.js service."
  }

  ifelse { s6-test ${LINES} -eq 1 }
  {
    if { s6-rmrf /var/run/s6/etc/services.d/nodejs/down }
    s6-echo -- "Single package.json found in '${PKGS}', default Node.js service will started."
  }

  foreground {
    elglob -0 -- downfiles /var/run/s6/etc/services.d/nodejs-*/down
    forx -p -- downfile { ${downfiles} }
    importas -u downfile downfile
    s6-rmrf ${downfile}
  }
  foreground { s6-echo -- "Multiple package.json found:" }
  foreground { s6-echo -- "${PKGS}" }
  s6-echo -- "[EXPERIMENTAL] Custom Node.js services will be started."


}
s6-echo -- "Node.js service init complete!"
