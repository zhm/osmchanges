# OpenStreetMap Changeset Sync for MongoDB

This script imports `changesets-latest.osm` [file](http://planet.osm.org/planet/) into MongoDB and also provides a way to keep the database up-to-date with the [minute diffs](http://planet.osm.org/replication/changesets/).

I wrote this little script to power the [pushpinapp stats](http://pushpinosm.org/stats/) and others might find it useful.

The changeset data is stored in the database in the following structure:

    {
      "id" : 14599774,
      "created_at" : ISODate("2013-01-10T16:34:19Z"),
      "closed_at" : ISODate("2013-01-10T16:38:19Z"),
      "open" : false,
      "user" : "VladUA",
      "uid" : 86339,
      "min_lat" : 50.2353668,
      "max_lat" : 50.235619,
      "min_lon" : 34.92974,
      "max_lon" : 34.9301396,
      "tags" : {
        "created_by" : "Potlatch 2",
        "comment" : "object's",
        "build" : "2.3-554-ge648197",
        "version" : "2.3"
      },
      "num_changes" : 10
    }

# Requirements

  * MongoDB
  * Ruby 1.9
  * Bundler `gem install bundler`
  * Download the `changesets-latest.osm.bz2` file from [here](http://planet.osm.org/planet/) and extract it somewhere for the first time import.

# Usage

    $ bundle
    $ ./osmchanges.rb import -f /path/to/changesets-latest.osm  # this will take a while

  Now you will need to find a sequence number that will work for the time you did the import. A safe bet is to look at the date on the changesets-latest.osm file you downloaded and go back half a day or so. Start [here](http://planet.osm.org/replication/changesets/000/) and drill all the way down to a specific file. You don't need to download the file, you just need to get the number. You will need the full sequence number. e.g. The sequence number for http://planet.osm.org/replication/changesets/000/020/999.osm.gz is 000020999. You will use this sequence number for the next command so the importer knows how to "catch up" and bootstrap the diff process. I would like to improve this, but since you only need to do this once, it's not a huge deal for now.

    $ ./osmchanges.rb sync -s 000020999  # use your sequence number

  Once this completes, your database will be up-to-date and ready to work with the minute diffs. The last state is now stored in the database and you only need to run one command at any time to sync the database with the diffs. To keep the database always up-to-date, just add the following command to a cronjob.

    $ ./osmchanges.rb sync

  Here is the crontab line I use

    */5 * * * * cd /apps/osmchanges/ && /usr/local/lib/ry/current/bin/ruby osmchanges.rb sync

  If you have trouble getting it running from a cronjob, it's most likely due to a ruby version or gem issue. Feel free to submit an issue.

# Making use of the data

There's a script in the repo that uses the changeset data to compute some basic edit statistics for Pushpin iOS. You can see how to query the data and make use of it to do something much cooler with your own script :)

You can run the pushpin stats script yourself to output a stats.json file:

    $ ./pushpin.rb stats
