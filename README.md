CPTextView
==========
this is an implementation of the cocoa text system for cappuccino.
this work is based on the (dead) cappuccino-fork from <http://github.com/emaillard/cappuccino>.

I extracted the classes CPTextView, CPTextStorage, CPTextContainer, CPLayoutManager and CPSimpleTypesetter to create a standalone framework. This framework compiles with the current version of cappuccino.
I heavily debugged the stuff to get basic editing and selection handling working as expected.
I replaced canvas-drawing with DOM-spans to addresss the immanent performance and rendering-quality issues.
The (buggy) CPAttributedString implementation from the cappuccino-proper is fixed through monkey-patching.

While the basic functionality is already there, a lot remains to do:
* Finish CPParagraphStyle (tab-stops, spacing)
* CPRulerView
* Native paste is broken on safari
* Compliance with cappuccino code-formatting guidelines (capp_lint)

Online demo is at <http://aug-fancy.ukl.uni-freiburg.de/CPTextView>

Please fork and help out!
