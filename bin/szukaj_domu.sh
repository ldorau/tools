#!/bin/bash

set -x

cd $HOME/work/nowydom/

rm ./gratka/ogloszenia/*
rm ./otodom/ogloszenia/*
rm ./trojmiasto/ogloszenia/*
rm ./*/ogloszenia/*

rm -f ./szukaj_domu.txt

szukaj_domu.py --no-email >> ./szukaj_domu.txt 2>&1
echo "                  " >> ./szukaj_domu.txt
szukaj_domu.py --no-email >> ./szukaj_domu.txt 2>&1
echo "                  " >> ./szukaj_domu.txt
szukaj_domu.py --no-email >> ./szukaj_domu.txt 2>&1

git add ./szukaj_domu.txt

git-auto-push $HOME/work/nowydom main
