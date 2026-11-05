{
  description = "home-manager module: play a sound when Claude Code needs your input";

  # No inputs on purpose. This flake exports a module and nothing else, so it
  # imposes no nixpkgs or home-manager pin on whoever consumes it.
  outputs = { self }:
    let
      module = import ./module.nix;
    in
    {
      homeModules = {
        claude-notify = module;
        default = module;
      };

      # Older attribute name, still what most flakes reach for.
      homeManagerModules = self.homeModules;
    };
}
