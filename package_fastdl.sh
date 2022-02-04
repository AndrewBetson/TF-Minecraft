#!/bin/sh

ROOT_DIR="$PWD"

cd "./game/tf/materials/models/minecraft/"

for i in *.vmt *.vtf; do
	[ -f "$i" ] || break
	echo "$i"
	bzip2 --best --keep "$i"
done

mkdir -p "$ROOT_DIR/fastdl/tf/materials/models/minecraft/"
mv -t "$ROOT_DIR/fastdl/tf/materials/models/minecraft/" *.bz2

cd "$ROOT_DIR/game/tf/models/minecraft/"

for i in *.*; do
	[ -f "$i" ] || break
	echo "$i"
	bzip2 --best --keep "$i"
done

mkdir -p "$ROOT_DIR/fastdl/tf/models/minecraft/"
mv -t "$ROOT_DIR/fastdl/tf/models/minecraft/" *.bz2

cd "$ROOT_DIR/game/tf/sound/minecraft/"

for i in *.mp3; do
	[ -f "$i" ] || break
	echo "$i"
	bzip2 --best --keep "$i"
done

mkdir -p "$ROOT_DIR/fastdl/tf/sound/minecraft/"
mv -t "$ROOT_DIR/fastdl/tf/sound/minecraft/" *.bz2
