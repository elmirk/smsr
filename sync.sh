#!/bin/bash
rsync -e ssh -rvzc --progress --include='*.h' --include='*.c' --include='*.erl' --include='*.hrl' --exclude='*' /home/elmir/smsr/ root@172.27.27.49:/opt/smsr/src
