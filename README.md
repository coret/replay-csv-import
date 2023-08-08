# replay-csv-import for Omeka S

A Bash script to "replay" an CSV import in Omeka S. Can be used to automate (eg. cronjon) the update of data in Omeka S from a CSV/TSV file. 

## Prerequisites

- This Bash script uses `jq` and `mysql`, these have to be installed on your system.
- Configuration of the Omeka S instance for the script can be done via the .env file, no need for changes in the .sh file.
- Omeka S database configuration is used from config/database.ini.

## Running the script

First, a manual import has to be done via the [Omeka S CSV import module](https://omeka.org/s/modules/CSVImport/). After this, the job details, including the mapping, can be replicated by calleing the replay-csv-import script with the job ID of the initial manual import and an updated CSV/TSV file. 

**Note**: this is only logical for update/revise imports and data with (persistent) identifiers.

```
bash replay-csv-import.sh -csv [filename of csv/tsv file from which the data is updated] -job [job id to replicatie]
```

**Beware**: this script uses the Omeka S `perform-job.php` (=the good), after directly inserting a (cloned) record into the `jobs` table in the Omeka database (=the bad). Use with caution!
