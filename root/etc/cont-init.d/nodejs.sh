#!/usr/bin/execlineb -P

with-contenv

importas -u NODE_ENV NODE_ENV

foreground {

  if -t { s6-test "${NODE_ENV}" = "development" }

  foreground {
    s6-mkdir -p /tmp/cont-init-env
  }

  foreground {
    redirfd -w 1 /tmp/cont-init-env/PKGDIR
    find /var/www/html/web/app/themes -mindepth 2 -maxdepth 2 -name "package.json" -type f -printf "%h" -quit
  }

  s6-envdir -fn -- /tmp/cont-init-env

  importas -u PKGDIR PKGDIR

  backtick -n LINES {
    pipeline {
      s6-echo -- ${PKGDIR}
    }
    grep -c .
  }
  importas -u LINES LINES

  ifelse { s6-test ${LINES} -eq 0 }
  {
    s6-echo -- "No package.json found, skipping Node.js service."
  }

  if -t { s6-test ${LINES} -eq 1 }
  if -t { s6-rmrf /var/run/s6/etc/services.d/nodejs/down }
  s6-echo -- "Single package.json found in '${PKGDIR}', development mode is active => default Node.js service will started."

}

s6-echo -- "Node.js service init complete!"
