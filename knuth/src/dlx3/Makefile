
dlx3:
	gcc -I/usr/local/sgb/include/ -Wall -O2 dlx3.c -o dlx3 -lgb

tangle:
	/usr/local/bin/ctangle dlx3.w dlx3-sharp.ch
	/usr/local/bin/cweave dlx3.w dlx3-sharp.ch

pdf:
	pdftex dlx3.tex
