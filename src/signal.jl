"""
A signal type for indicating a particular signal should be processed.
"""
struct Signal{S <: Symbol} end
@inline Signal(S::Symbol) = Signal{S}()

"""
Issue a signal to all problem owners.

# Example

To signal that the correction step has finished (irrespective of success)
```
signal!(Signal(:post_correct), problem)
```
"""
function signal! end
