{ attr-json, run-tests ? false }:

with builtins;
let
  pkgs = import <nixpkgs> {
    config = import (getEnv "NIXPKGS_CONFIG") // {
      allowBroken = false;
    };
  };

  inherit (pkgs) lib;

  attrs = fromJSON (readFile attr-json);
  getProperties = name:
    let
      attrPath = lib.splitString "." name;
      pkg = lib.attrByPath attrPath null pkgs;
      exists = lib.hasAttrByPath attrPath pkgs;

      tests-attrs =
        if (!run-tests || pkg == null)
          then []
          else lib.flip map (builtins.attrNames (pkg.tests or {})) (test:
            let
              attrPath = [ "tests" test ];
              test-derivation = lib.attrByPath attrPath null pkg;

              maybePath = tryEval "${lib.getOutput "out" pkg}";
              broken = !(exists && maybePath.success);
              # exists = lib.hasAttrByPath attrPath pkg;

              # maybePath = tryEval "${lib.getOutput "out" test-derivation}";
            in
              lib.nameValuePair "${name}.tests.${test}"
              {
                inherit broken exists;
                # path = if !broken then maybePath.value else null;
                path = maybePath.value;
                # drvPath = if !broken then test-derivation.drvPath else null;
                drvPath = test-derivation.drvPath or null;
              }
            );

      package-attrs =
        if pkg == null then
          [
            (lib.nameValuePair name {
              inherit exists;
              broken = true;
              path = null;
              drvPath = null;
            })
          ]
        else
          lib.flip map pkg.outputs or [ "out" ] (output:
            let
              # some packages are set to null if they aren't compatible with a platform or package set
              maybePath = tryEval "${lib.getOutput output pkg}";
              broken = !exists || !maybePath.success;
            in
            lib.nameValuePair
              (if output == "out" then name else "${name}.${output}")
              {
                inherit exists broken;
                path = if !broken then maybePath.value else null;
                drvPath = if !broken then pkg.drvPath else null;
              }
          );
        in package-attrs ++ tests-attrs;
in

listToAttrs (concatMap getProperties attrs)
