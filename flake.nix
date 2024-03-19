{
  description = "Determinate Nix";
  inputs = {
    nix.url = "https://flakehub.com/f/NixOS/nix/2.21";
    nixpkgs.url = "https://flakehub.com/f/NixOS/nixpkgs/*";
  };

  outputs = { self, nix, nixpkgs, ... }:
    let
      lib = nixpkgs.lib;
      targetedSystems = [
        "aarch64-darwin"
        "aarch64-linux"
        "x86_64-darwin"
        "x86_64-linux"

        "i686-linux" # Not supported by Determinate Nix Installer
      ];

      forSystems = s: f: lib.genAttrs s (system: f rec {
        inherit system;
        pkgs = nixpkgs.legacyPackages.${system};
      });

      forAllSystems = forSystems targetedSystems;
    in
    {
      closures = forAllSystems ({ system, ... }: nix.packages."${system}".default);
      checks = forAllSystems ({ system, ... }: {
        fetchable = nix.packages."${system}".default;
      });

      packages = forAllSystems ({ system, pkgs, ... }: {
        closures_json = pkgs.runCommand "versions.json"
          {
            buildInputs = [ pkgs.jq ];
            passAsFile = [ "json" ];
            json = builtins.toJSON (self.closures);
          } ''
          cat "$jsonPath" | jq . > $out
        '';

        closures_nix = pkgs.runCommand "versions.nix"
          {
            buildInputs = [ pkgs.jq ];
            passAsFile = [ "template" ];
            jsonPath = self.packages.${system}.closures_json;
            template = ''
              # Generated by https://github.com/DeterminateSystems/nix-upgrade based on the
              # flake at https://flakehub.com/flake/NixOS/nix, which is a mirror of the
              # upstream NixOS/nix project.
              builtins.fromJSON('''@closures@''')
            '';
          } ''
          export closures=$(cat "$jsonPath");
          substituteAll "$templatePath" "$out"
        '';
      });
    };
}
