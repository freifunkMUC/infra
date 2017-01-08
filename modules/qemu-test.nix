{ ... }:

{
  virtualisation.graphics = false;

  # Automatically log in at the virtual consoles.
  services.mingetty.autologinUser = "root";

  # Allow the user to log in as root without a password.
  users.extraUsers.root.initialHashedPassword = "";
}
