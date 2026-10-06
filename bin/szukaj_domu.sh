#!/bin/bash

set -x

cd $HOME/work/nowydom/

rm ./gratka/ogloszenia/*
rm ./otodom/ogloszenia/*
rm ./trojmiasto/ogloszenia/*
rm ./*/ogloszenia/*

szukaj_domu.py --no-email >  ./szukaj_domu.txt 2>&1
szukaj_domu.py --no-email >> ./szukaj_domu.txt 2>&1
szukaj_domu.py --no-email >> ./szukaj_domu.txt 2>&1

git add ./szukaj_domu.txt

git-auto-push $HOME/work/nowydom main
