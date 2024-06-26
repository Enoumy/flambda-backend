#**************************************************************************
#*                                                                        *
#*                                 OCaml                                  *
#*                                                                        *
#*            Sebastien Hinderer, projet Gallium, INRIA Paris             *
#*                                                                        *
#*   Copyright 2016 Institut National de Recherche en Informatique et     *
#*     en Automatique.                                                    *
#*                                                                        *
#*   All rights reserved.  This file is distributed under the terms of    *
#*   the GNU Lesser General Public License version 2.1, with the          *
#*   special exception on linking described in the file LICENSE.          *
#*                                                                        *
#**************************************************************************

# The Makefile for ocamltest

ROOTDIR = ..

include $(ROOTDIR)/Makefile.common
include $(ROOTDIR)/Makefile.best_binaries

# List of source files from which ocamltest is compiled
# (all the different sorts of files are derived from this)

# ocamltest has two components: its core and the OCaml "plugin"
# which is actually built into the tool but clearly separated from its core

core := \
  run_$(UNIX_OR_WIN32).c run_stubs.c \
  ocamltest_config.mli ocamltest_config.ml.in \
  ocamltest_unix.mli ocamltest_unix.ml \
  ocamltest_stdlib.mli ocamltest_stdlib.ml \
  run_command.mli run_command.ml \
  filecompare.mli filecompare.ml \
  variables.mli variables.ml \
  environments.mli environments.ml \
  result.mli result.ml \
  actions.mli actions.ml \
  tests.mli tests.ml \
  strace.mli strace.ml \
  tsl_ast.mli tsl_ast.ml \
  tsl_parser.mly \
  tsl_lexer.mli tsl_lexer.mll \
  modifier_parser.mli modifier_parser.ml \
  tsl_semantics.mli tsl_semantics.ml \
  builtin_variables.mli builtin_variables.ml \
  actions_helpers.mli actions_helpers.ml \
  builtin_actions.mli builtin_actions.ml \
  translate.mli translate.ml

ocaml_plugin := \
  ocaml_backends.mli ocaml_backends.ml \
  ocaml_filetypes.mli ocaml_filetypes.ml \
  ocaml_variables.mli ocaml_variables.ml \
  ocaml_directories.mli ocaml_directories.ml \
  ocaml_modifiers.mli ocaml_modifiers.ml \
  ocaml_files.mli ocaml_files.ml \
  ocaml_flags.mli ocaml_flags.ml \
  ocaml_commands.mli ocaml_commands.ml \
  ocaml_tools.mli ocaml_tools.ml \
  ocaml_compilers.mli ocaml_compilers.ml \
  ocaml_toplevels.mli ocaml_toplevels.ml \
  ocaml_actions.mli ocaml_actions.ml \
  ocaml_tests.mli ocaml_tests.ml

sources := $(core) $(ocaml_plugin) \
  options.mli options.ml \
  main.mli main.ml

# List of .ml files used for ocamldep and to get the list of modules

ml_files := \
  $(filter %.ml, \
    $(subst .ml.in,.ml,$(subst .mll,.ml,$(subst .mly,.ml,$(sources)))) \
  )

cmo_files := $(ml_files:.ml=.cmo)

cmx_files := $(ml_files:.ml=.cmx)

# List of .mli files for ocamldep
mli_files := \
  $(filter %.mli,$(subst .mly,.mli,$(sources)))

cmi_files := $(mli_files:.mli=.cmi)

c_files := $(filter %.c, $(sources))

o_files := $(c_files:.c=.$(O))

lexers := $(filter %.mll,$(sources))

parsers := $(filter %.mly,$(sources))

dependencies_generated_prereqs := \
  ocamltest_unix.ml \
  $(lexers:.mll=.ml) \
  $(parsers:.mly=.mli) $(parsers:.mly=.ml)

generated := $(dependencies_generated_prereqs) $(parsers:.mly=.output)

bytecode_modules := $(o_files) $(cmo_files)

native_modules := $(o_files) $(cmx_files)

directories := $(addprefix $(ROOTDIR)/,utils bytecomp parsing \
                                       compilerlibs file_formats)

include_directories := $(addprefix -I , $(directories))

flags := $(STDLIBFLAGS) -g $(include_directories) \
  -strict-sequence -strict-formats \
  -w +a-4-9-41-42-44-45-48 -warn-error +A

ocamlc = $(BEST_OCAMLC) $(flags)

ocamlopt = $(BEST_OCAMLOPT) $(flags)

.SECONDARY: $(lexers:.mll=.ml) $(parsers:.mly=.mli) $(parsers:.mly=.ml)

.PHONY: all allopt opt.opt # allopt and opt.opt are synonyms
all: ocamltest$(EXE)
allopt: ocamltest.opt$(EXE)
opt.opt: allopt

compdeps_names=ocamlcommon ocamlbytecomp
compdeps_paths=$(addprefix $(ROOTDIR)/compilerlibs/,$(compdeps_names))
deps_paths = \
  $(compdeps_paths) $(addprefix $(ocamltest_unix_path)/,$(ocamltest_unix_name))
deps_byte=$(addsuffix .cma,$(deps_paths))
deps_opt=$(addsuffix .cmxa,$(deps_paths))

$(eval $(call PROGRAM_SYNONYM,ocamltest))

ocamltest_unix.%: flags+=$(ocamltest_unix_include) -opaque

ocamltest$(EXE): $(deps_byte) $(bytecode_modules)
	$(V_LINKC)$(ocamlc_cmd) $(ocamltest_unix_include)-custom -o $@ $^

%.cmo: %.ml $(deps_byte)
	$(V_OCAMLC)$(ocamlc) -c $<

$(eval $(call PROGRAM_SYNONYM,ocamltest.opt))

ocamltest.opt$(EXE): $(deps_opt) $(native_modules)
	$(V_LINKOPT)$(ocamlopt_cmd) $(ocamltest_unix_include)-o $@ $^

%.cmx: %.ml $(deps_opt)
	$(V_OCAMLOPT)$(ocamlopt) -c $<

%.cmi: %.mli $(deps_byte)
	$(V_OCAMLC)$(ocamlc) -c $<

ocamltest_unix.ml: ocamltest_unix.$(ocamltest_unix_impl).ml
	$(V_GEN)echo '# 1 "$<"' > $@ && \
	cat $< >> $@

# Manual

.PHONY: doc

doc: ocamltest.html

ocamltest.html: ocamltest.org
	pandoc -s --toc -N -f org -t html -o $@ $<

.PHONY: clean
clean:
	rm -rf ocamltest ocamltest.exe ocamltest.opt ocamltest.opt.exe
	rm -rf *.o *.obj *.cm*
	rm -rf $(generated)
	rm -f ocamltest.html
	rm -rf $(DEPDIR)

ifeq "$(COMPUTE_DEPS)" "true"
include $(addprefix $(DEPDIR)/, $(c_files:.c=.$(D)))
endif

.PHONY: distclean
distclean: clean
	rm -f ocamltest_config.ml

$(DEPDIR)/%.$(D): %.c | $(DEPDIR)
	$(V_CCDEPS)$(DEP_CC) $(OC_CPPFLAGS) $(CPPFLAGS) $< -MT '$*.$(O)' -MF $@

.PHONY: depend
depend: $(dependencies_generated_prereqs)
	$(V_OCAMLDEP)$(OCAMLDEP_CMD) $(mli_files) $(ml_files) > .depend

-include .depend
