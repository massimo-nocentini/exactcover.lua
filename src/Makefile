

linux:
	gcc -O3 -g -fPIC -Wall -shared -I/usr/local/sgb/include/ -o libdlx1.so libdlx1.c -llua -lgb
	gcc -O3 -g -fPIC -Wall -shared -I/usr/local/sgb/include/ -o libdlxgenerator.so libdlxgenerator.c -llua -lgb

install:
	mkdir -p /usr/local/lib/lua/5.4/	# just for ensuring that the dest dir exists
	mkdir -p /usr/local/share/lua/5.4/	# just for ensuring that the dest dir exists
	mv libdlx1.so libdlxgenerator.so /usr/local/lib/lua/5.4/
	cp dlx.lua /usr/local/share/lua/5.4/

test:
	cd ../test && lua test-dlx1.lua && lua test-dlxgenerator.lua