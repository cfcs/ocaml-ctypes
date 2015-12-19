if test $COVERAGE -a $TRAVIS_OS_NAME != osx ; then
    USE_BISECT=true;
fi

OPAM_DEPENDS="ocamlfind ounit"
if test $USE_BISECT ; then
    OPAM_DEPENDS="$OPAM_DEPENDS bisect_ppx ocveralls"
    MAKE="make COVERAGE=true"
else
    MAKE="make"
fi
case "$OCAML_VERSION" in
4.00.1) ppa=avsm/ocaml40+opam12 ;;
4.01.0) ppa=avsm/ocaml41+opam12 ;;
4.02.3) ppa=avsm/ocaml42+opam12 ;;
*) echo Unknown $OCAML_VERSION; exit 1 ;;
esac

install_on_linux () {
  echo "yes" | sudo add-apt-repository ppa:$ppa
  sudo apt-get update -qq
  sudo apt-get install -qq ocaml ocaml-native-compilers camlp4-extra opam
  opam init
  opam update
}

install_on_osx () {
  curl -OL "http://xquartz.macosforge.org/downloads/SL/XQuartz-2.7.6.dmg"
  sudo hdiutil attach XQuartz-2.7.6.dmg
  sudo installer -verbose -pkg /Volumes/XQuartz-2.7.6/XQuartz.pkg -target /
  brew update
  brew reinstall ocaml
  brew install libffi opam
  opam init
  opam switch $OCAML_VERSION
  eval `opam config env` 
}

export OPAMYES=1
export OPAMVERBOSE=1

echo $TRAVIS_OS_NAME
case $TRAVIS_OS_NAME in
  osx) install_on_osx ;;
  linux) install_on_linux ;;
esac

echo OCaml version
ocaml -version
echo OPAM versions
opam --version
opam --git-version
opam install ${OPAM_DEPENDS}
eval `opam config env`
$MAKE
# build and run the tests
$MAKE test
# build and run the examples
$MAKE examples
_build/date.native
_build/date-cmd.native
_build/fts-cmd.native examples

if test $USE_BISECT ; then
    ocveralls --send bisect*.out _build/bisect*.out > coveralls.json
fi

# check Xen support builds too
set -eu
case "$OCAML_VERSION" in
4.00.*)
  echo "OCaml too old; not testing Mirage" ;;
*)
  if opam install mirage-xen; then
    make XEN=enable
    ls -l _build/libctypes_stubs_xen.a
  else
    echo "Mirage not installable, so not testing Xen build."
  fi ;;
esac
