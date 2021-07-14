import tableformatter as tf
from colorama import Back
#from colored import fg, bg, attr
from prettytable import PrettyTable

tbl = PrettyTable()
tbl.field_names = ["Name", "Country", "Num kids", "Is kid"]
tbl.add_row(["Evka", "Lithuania", 1, False])
tbl.add_row(["Juozas", "Lithuania", 0, True])
tbl.add_row(["Agne", "Lithuania", 1, False])
tbl.add_row(["Valdas", "Lithuania", 3, False])
tbl.align = "l"

print(tbl)

def my_row_colorer(rows):
    opts = {}
    if rows[2] == 0:
       opts[tf.TableFormatter.ROW_OPT_TEXT_COLOR] = tf.TableColors.TEXT_COLOR_RED
       # opts[tf.TableFormatter.ROW_OPT_TEXT_BACKGROUND] = Back.LIGHTRED_EX
    return opts

cols = ["Name", "Country", "Num kids", "Is kid"]
rows = [("Evka", "Lithuania", 1, False),
         ("Juozas", "Lithuania", 0, True),
         ("Agne", "Lithuania", 1, False),
         ("Valdas", "Lithuania", 3, False)]

print(tf.generate_table(rows, cols, grid_style=tf.FancyGrid(), row_tagger=my_row_colorer))
print(tf.generate_table(rows, cols, row_tagger=my_row_colorer))
