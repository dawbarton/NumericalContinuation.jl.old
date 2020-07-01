using DocStringExtensions

@template TYPES = """
    $(TYPEDEF)
    $(DOCSTRING)

    # Fields

    $(TYPEDFIELDS)
    """

@template (FUNCTIONS, METHODS, MACROS) = """
    $(SIGNATURES)
    $(DOCSTRING)
    """

@template MODULES = """
    $(DOCSTRING)

    # Exports

    $(EXPORTS)
    """
