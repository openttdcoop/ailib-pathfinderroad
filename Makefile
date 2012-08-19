# Configuration
LIB_NAME = Pathfinder.Road
LIB_VERSION = 4
FILES = COPYING main.nut library.nut changelog.txt
# End of configuration

NAME_VERSION = $(LIB_NAME).$(LIB_VERSION)
TAR_NAME_NOAI = $(NAME_VERSION)-noai.tar
TAR_NAME_NOGO = $(NAME_VERSION)-nogo.tar


all: noai-bundle nogo-bundle

noai-bundle: Makefile $(FILES)
	@mkdir "$(NAME_VERSION)"
	@cp $(FILES) "$(NAME_VERSION)"
	@tar -cf "$(TAR_NAME_NOAI)" "$(NAME_VERSION)"
	@rm -r "$(NAME_VERSION)"


nogo-bundle: Makefile $(FILES)
	@mkdir "$(NAME_VERSION)"
	@cp $(FILES) "$(NAME_VERSION)"
	@sed "s/\bAI/GS/g" -i "$(NAME_VERSION)"/*.nut
	@tar -cf "$(TAR_NAME_NOGO)" "$(NAME_VERSION)"
	@rm -r "$(NAME_VERSION)"
