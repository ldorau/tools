#!/bin/bash

set -x

szukaj_domu.py
git-auto-push $HOME/work/nowydom main

cd $HOME/work/nowydom/
rm ./gratka/ogloszenia/*
rm ./otodom/ogloszenia/*
rm ./trojmiasto/ogloszenia/*
rm ./*/ogloszenia/*

LOG=./szukaj_domu.log
rm -f $LOG

szukaj_domu.py --no-email >> $LOG 2>&1
echo "                  " >> $LOG
szukaj_domu.py --no-email >> $LOG 2>&1
echo "                  " >> $LOG
szukaj_domu.py --no-email >> $LOG 2>&1

git add $LOG
git-auto-push $HOME/work/nowydom main
