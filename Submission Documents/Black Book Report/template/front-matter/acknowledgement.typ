#import "/config.typ": *

#set text(font: "Times New Roman")

#align(center)[#text(size: 16pt, weight: "bold")[ACKNOWLEDGEMENT]]

#v(2em)

#include "/content/acknowledgement.typ"


#align(right+bottom)[
  #block(width: auto)[
    #set align(left)
    #for (name, roll, division, seat) in dataset [
      *#name*

    ]
  ]
]

#pagebreak()
