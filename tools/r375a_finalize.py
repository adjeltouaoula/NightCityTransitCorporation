from pathlib import Path

transit = Path('source/redscript/NCTC/NCTCTransitSystem.reds')
s = transit.read_text(encoding='utf-8')
old = '''    this.boardingDoorWasOpen = false;\n    this.departureRequested = false;\n    this.bayParkingWasEntered = false;'''
new = '''    this.boardingDoorWasOpen = false;\n    this.departureRequested = false;\n    this.bayParkingActive = false;\n    this.bayParkingStage = 0;\n    this.bayParkingWasEntered = false;'''
assert old in s, 'despawn reset anchor missing'
s = s.replace(old, new, 1)
s = s.replace('        this.bayParkingStage = 0;\n            this.driveCommandSent = false;', '        this.bayParkingStage = 0;\n        this.driveCommandSent = false;')
transit.write_text(s, encoding='utf-8')

cet = Path('source/cet/nctc_survey/init.lua')
c = cet.read_text(encoding='utf-8')
old_table = '''    [53] = "route loop: r374w 3-to-1 rolling REJOIN",\n    [54] = "route loop: r374w direct departure stall recovery"\n'''
new_table = '''    [53] = "route loop: r374w 3-to-1 rolling REJOIN",\n    [54] = "route loop: r374w direct departure stall recovery",\n    [60] = "route loop: r375a bay entry ray",\n    [61] = "route loop: r375a final parking target",\n    [62] = "route loop: r375a parked in bay",\n    [63] = "route loop: r375a bay exit/rejoin",\n    [64] = "route loop: r375a intermediate bay skipped",\n    [65] = "route loop: r375a entry retry",\n    [66] = "route loop: r375a parking retry",\n    [67] = "route loop: r375a exit retry"\n'''
assert old_table in c, 'CET code table anchor missing'
c = c.replace(old_table, new_table, 1)
cet.write_text(c, encoding='utf-8')

print('r375a finalizer applied')
