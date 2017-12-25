#!/bin/sh

set -e

repositories_path=/var/lib/svn
dumps_path=/var/lib/svn-dumped

chgrp www-data /etc/apache2/ht{users,groups}
chmod g+r /etc/apache2/ht{users,groups}

chown -R www-data:www-data $repositories_path $dumps_path
chmod -R u+rw $repositories_path $dumps_path

case $1 in
  create)
    shift
    names=$@
    for n in $names
    do
      sudo -u www-data svnadmin create $repositories_path/$n
    done
    ;;

  destroy)
    shift
    exec rm -rf "$@"
    ;;

  dump)
    shift
    names=$@
    test '' = "$names" && names=`ls $repositories_path`

    for n in $names
    do
      input_path=$repositories_path/$n
      output_path=$dumps_path/$n
      install -m 755 -o www-data -g www-data -d $output_path
      sudo -u www-data svn-backup-dumps -b -q -c 1 $input_path $output_path |
          sed -e '/^$/ d' \
              -e '/ already exists.$/ d' \
              -e '/^writing / d' \
              -e '/^Everything OK.$/ d'
    done
    ;;

  restore)
    shift
    names=$@
    test '' = "$names" && names=`ls $dumps_path`

    for n in $names
    do
      input_path=$dumps_path/$n
      output_path=$repositories_path/$n

      test -d $input_path || continue

      sudo -u www-data svnadmin create $output_path
      for path in `ls $input_path/*`
      do
        case $path in
          *.gz)
            load_command=zcat
            ;;
          *.bz2)
            load_command=bzcat
            ;;
          *)
            load_command=cat
            ;;
        esac
        $load_command $path |
            sudo -u www-data svnadmin load $output_path
      done
    done
    ;;

  *)
    exec "$@"
    ;;
esac
