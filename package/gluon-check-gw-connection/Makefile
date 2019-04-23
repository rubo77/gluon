include $(TOPDIR)/rules.mk

PKG_NAME:=gluon-check-gw-connection
PKG_VERSION:=1

include ../gluon.mk

define Package/gluon-check-gw-connection
  TITLE:=Checks if abatman connection exists to a gateway
  DEPENDS:=+gluon-core
endef

$(eval $(call BuildPackageGluon,gluon-check-gw-connection))
