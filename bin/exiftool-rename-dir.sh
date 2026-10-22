#!/bin/bash

exiftool -m "-FileName<CreateDate" -d "%Y-%m-%d/%Y%m%d_%H%M%S-%%f.%%e" *
