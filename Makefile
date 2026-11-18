# make test | app | dmg | clean
.PHONY: test app dmg clean

test:
	tests/run.sh

app:
	packaging/build-app.sh

dmg:
	packaging/make-dmg.sh

clean:
	rm -rf build dist
