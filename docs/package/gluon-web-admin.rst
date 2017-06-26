gluon-web-admin
===============

This package allows the user to set options like the password for ssh access
within config mode. You can define in your site.conf whether it should be
possible to access the nodes via ssh with a password or not.

site.conf
---------

config_mode.remote_login.allow_password_login \: optional (defaults to true)
  If ``allow_password_login`` is set to ``false``, the password section in
  config mode is hidden

Example::

  config_mode = {
    remote_login = {
      allow_password_login = true
    }
  }
