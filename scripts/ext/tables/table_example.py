from common.utils import *
from prettytable import PrettyTable # if you want to use the prettytable instead of tableformatter (which is included in the common.utils)

################### prettytable ###################
tbl = PrettyTable()
tbl.field_names = ["Name", "Country", "Num kids", "Is kid"]
tbl.add_row(["Evka", "Lithuania", 1, False])
tbl.add_row(["Juozas", "Lithuania", 0, True])
tbl.add_row(["Agne", "Lithuania", 1, False])
tbl.add_row(["Valdas", "Lithuania", 3, False])
tbl.add_row(["Andrew", "U.S.", "UNKNOWN :)", False])
tbl.align = "l"

print(tbl)


################### tableformatter ###################
## (this one looks better IMO)
cols = ["Name", "Country", "Num kids", "Is kid"]
rows = [("Evka", "Lithuania", 1, False),
        ("Juozas", "Lithuania", 0, True),
        ("Agne", "Lithuania", 1, False),
        ("Valdas", "Lithuania", 3, False),
        ("Andrew", "U.S.", "UNKNOWN :)", False)]

print(tf.generate_table(rows, cols)) ### <== this one, or the one below should probably be most commonly used
print(tf.generate_table(rows, cols, grid_style=FULL_TABLE_GRID_STYLE))

# if you want to color some rows, you can do the following (although may not work well if you're using color prints from the RegVal)
def my_row_colorer(rows):
    opts = {}
    if rows[2] == 0:
        opts[tf.TableFormatter.ROW_OPT_TEXT_COLOR] = tf.TableColors.TEXT_COLOR_RED
        # opts[tf.TableFormatter.ROW_OPT_TEXT_BACKGROUND] = Back.LIGHTRED_EX
    return opts

print(tf.generate_table(rows, cols, row_tagger=my_row_colorer))
print(tf.generate_table(rows, cols, grid_style=FULL_TABLE_GRID_STYLE, row_tagger=my_row_colorer))
