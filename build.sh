cd bin
../rasm -s ../src/termM4.s
../rasm ../src/charset.s
../rasm ../src/telnet.s
cp ./EWENM4.BIN ~/Library/"Application Support"/CPCemu/SDCARD/.
cp ./TELNETE.BIN ~/Library/"Application Support"/CPCemu/SDCARD/.
cp ./CHARSET.BIN ~/Library/"Application Support"/CPCemu/SDCARD/.
cd ..
