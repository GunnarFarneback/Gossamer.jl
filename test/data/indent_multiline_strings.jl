# Just don't try to reindent multiline strings or command literals.
docstring =
"""
    f()

Apply f.
"""
##
docstring =
    """
        f()
    
    Apply f.
    """
##
docstring = """
        f()
    
    Apply f.
    """
##
docstring =
raw"""
    f()

Apply f.
"""
##
docstring =
    raw"""
        f()
    
    Apply f.
    """
##
docstring = raw"""
        f()
    
    Apply f.
    """
##
cmd =
```
git --version
```
##
cmd =
    ```
    git --version
    ```
##
cmd = ```
    git --version
    ```
