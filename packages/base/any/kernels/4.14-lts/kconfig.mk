############################################################
# <bsn.cl fy=2015 v=onl>
#
#           Copyright 2015 Big Switch Networks, Inc.
#
# Licensed under the Eclipse Public License, Version 1.0 (the
# "License"); you may not use this file except in compliance
# with the License. You may obtain a copy of the License at
#
#        http://www.eclipse.org/legal/epl-v10.html
#
# Unless required by applicable law or agreed to in writing,
# software distributed under the License is distributed on an
# "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND,
# either express or implied. See the License for the specific
# language governing permissions and limitations under the
# License.
#
# </bsn.cl>
############################################################
THIS_DIR := $(abspath $(dir $(lastword $(MAKEFILE_LIST))))
K_MAJOR_VERSION := 4
K_PATCH_LEVEL := 14
# Pinned to 4.14.49 to match the prebuilt bf_kdrv.ko vermagic shipped in
# stratumproject/stratum-bfrt:9.2.0 (which only has .ko files for
# 4.14.49, 4.15.0, 4.9.75, 3.16.56). Loading bf_kdrv against 4.14.151
# fails with "version magic '4.14.49-OpenNetworkLinux SMP mod_unload '
# should be '4.14.151-OpenNetworkLinux SMP mod_unload '". Stratum can't
# init the ASIC without that driver.
K_SUB_LEVEL := 49
K_SUFFIX :=
K_PATCH_DIR := $(THIS_DIR)/patches
K_MODSYNCLIST := tools/objtool
