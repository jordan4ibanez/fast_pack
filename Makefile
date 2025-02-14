default:
	@dub test

fast:
	@DFLAGS="-release -unittest" dub test

clean:
	dub clean