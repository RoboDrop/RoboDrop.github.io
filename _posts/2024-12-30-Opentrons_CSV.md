---
layout: post
title: "CSV Runtime parameters"
date: 2024-12-30
featured_image: /assets/images/posts/2024-12-30-Opentrons_CSV/runtimeCSV.png
---

Opentrons recently updated their app to accept a CSV as runtime parameters. I did a quick runthrough of the code to see how this works.


The Opentrons App is a great way to get started with liquid handling, however one of the pain points is generating a python file for every run. This can be a intimidating for the python beginner or plain repetitive if you're using the Opentrons for the same workflow with varying inputs. 

One of my workflows involved diluting twist fragments at the plate level, I wrote a python script that would generate another python script when given a CSV file with plate info. This worked fine but it did feel hacky and tended to needlessly fill up the Opentrons app with one time use scripts.

This latest update to the opentrons app (8.0, released Sept 2024) allows you to define your base script, upload it to their app and then vary the input by selecting a CSV file to run the script with. This makes a great user experience for the Scientist that needs their machine to do x job given y data.

To add a CSV parameter funcitonality define the add_parameters and pass it an instance of the API parameters

```python
from opentrons import protocol_api
import csv

requirements = {"apiLevel": "2.21"}

def add_parameters(parameters: protocol_api.Parameters):
    parameters.add_csv_file(
        variable_name="your_csv_file",
        display_name="csv_display",
        description="csv_description.",
    )
```

Doing this allows you to access your CSV file in the main run() block. From here you can add whatever functions you would like to process the file and vary your pipetting steps.

The following script can accept a CSV file that accompanies every Twist Bioscience plate order which has the well location in the 4th column, the insert length in the 5th column and the nanograms in the 9th column. This script can live on your opentrons App and be used and reused to dilute every twist plate you receive to 50fmol/uL with varying CSV inputs.

```python
from opentrons import protocol_api
import csv

requirements = {"apiLevel": "2.21"}


# Define runtime parameters
def add_parameters(parameters: protocol_api.Parameters):
    parameters.add_csv_file(
        variable_name="twist_data",
        display_name="Twist Manifest CSV",
        description="Twist Manifest CSV.",
    )


# Main protocol function
def run(protocol: protocol_api.ProtocolContext):
    # Labware setup
    water_reservoir = protocol.load_labware('nest_1_reservoir_195ml', '10')
    tiprack_300 = protocol.load_labware('opentrons_96_tiprack_300ul', '11')
    tiprack_20 = protocol.load_labware('opentrons_96_tiprack_20ul', '9')
    well_plate = protocol.load_labware('nest_96_wellplate_200ul_flat', '1')

    # Pipette setup
    p300 = protocol.load_instrument('p300_single_gen2', 'left', tip_racks=[tiprack_300])
    p20 = protocol.load_instrument('p20_single_gen2', 'right', tip_racks=[tiprack_20])

    # Constants
    TARGET_CONCENTRATION = 50  # fmol/µL
    DNA_MW = 650  # Approximate molecular weight of 1 bp DNA in g/mol

    # Function to calculate water volume needed
    def calculate_water_volume(yield_ng, insert_length):
        try:
            # Calculate concentration in fmol/µL
            dna_conc_fmol_per_ul = (yield_ng / insert_length) / DNA_MW * 1e6
            if dna_conc_fmol_per_ul <= TARGET_CONCENTRATION:
                return 0  # No water needed
            dilution_factor = dna_conc_fmol_per_ul / TARGET_CONCENTRATION
            return (dilution_factor - 1) * yield_ng / dna_conc_fmol_per_ul
        except ZeroDivisionError:
            protocol.comment("Skipping due to invalid data.")
            return 0

        # Read the CSV file
    csv_file = protocol.params.twist_data.file
    csv_reader = csv.reader(csv_file)
    # Skip the header row
    header = next(csv_reader)
    protocol.comment(f"CSV Headers: {header}")

    for row in csv_reader:
        try:
            # Access data using zero-based indexing
            well_location = row[3]  # Assuming 'Well Location' is the 4th column
            yield_ng = float(row[8])  # Assuming 'Yield (ng)' is the 9th column
            insert_length = float(row[4])  # Assuming 'Insert Length' is the 5th column

            # Calculate required water volume
            water_volume = calculate_water_volume(yield_ng, insert_length)
            protocol.comment(f"Calculated water volume: {water_volume}")

            if water_volume > 0:
                # Select appropriate pipette
                pipette = p300 if water_volume > 20 else p20
                pipette.pick_up_tip()
                pipette.aspirate(water_volume, water_reservoir.wells()[0])
                pipette.dispense(water_volume, well_plate[well_location])
                pipette.drop_tip()
        except Exception as e:
            protocol.comment(f"Error processing row: {e} - Row data: {row}")
```
