# PaprikaPlate

A script for exporting your Pepperplate recipes to a format that Paprika 3 can import.

## Prerequisites

* **Chrome**: the script uses Chrome in headless mode to scrape Pepperplate data.
* **Ruby**: to run the script. Versions 2.5.5 and up should be compatible; older versions may not be.

## Installation

Run `bundle install --without development`.

## Running it

Run `ruby paprika_plate.rb`. You will be prompted for your Pepperplate username and password. If the script completes without any issues, your recipes should be saved to `recipes.yaml`.
