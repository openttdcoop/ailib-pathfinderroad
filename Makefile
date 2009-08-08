# Configuration
LIB_NAME = Queue.FibonacciHeap
LIB_VERSION = 1
FILES = COPYING main.nut library.nut
# End of configuration

NAME_VERSION = $(LIB_NAME).$(LIB_VERSION)
TAR_NAME = $(NAME_VERSION).tar


all: bundle

bundle: Makefile $(FILES)
	@mkdir "$(NAME_VERSION)"
	@cp $(FILES) "$(NAME_VERSION)"
	@tar -cf "$(TAR_NAME)" "$(NAME_VERSION)"
	@rm -r "$(NAME_VERSION)"
