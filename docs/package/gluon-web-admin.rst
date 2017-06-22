gluon-web-admin
===============

This package allows the user to set options like the password for ssh access
within config mode. You can define in your site.conf whether it should be
possible to access the nodes via ssh with a password or not and what the mimimum
password length must be.

site.conf
---------

config_mode.remote_login.allow_password_login \: optional (defaults to true)
  If ``allow_password_login`` is set to ``false``, the password section in
  config mode is hidden
  
config_mode.remote_login.min_password_length \: optional (defaults to '8')
  This sets the minimum allowed password length. Set this to '0' to
  disable the length check

Example::

  config_mode = {
    remote_login = {
      allow_password_login = true,
      min_password_length = '10'
    }
  }
