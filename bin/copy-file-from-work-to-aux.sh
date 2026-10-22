#!/bin/bash

FILES="$*"
DIR=~/work/aux

ls -alh $FILES
cp -v $FILES $DIR
git-auto-push $DIR
