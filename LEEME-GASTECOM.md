# Gastecom Softphone para PC (Windows)

Fork de [linphone-desktop](https://github.com/BelledonneCommunications/linphone-desktop),
distribuido bajo GPLv3 (ver `LICENSE.txt`).

- `gastecom/sdk/`: cambios propios sobre el SDK de Linphone (`external/linphone-sdk`,
  rama 5.5): secretos fuera del log en belle-sip y liblinphone, y nombre de los
  contactos LDAP. Se aplican con `git am` dentro de `external/linphone-sdk`.
- `gastecom/build/`: scripts con los que se compila el instalador (`configurar.bat`,
  `compilar.bat`, `desplegar.bat`...). La firma del instalador usa un certificado
  que no forma parte de este repositorio.
