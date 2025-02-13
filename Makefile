default:
	@dub run

fast:
	@dub run --build=release

clean:
	dub clean