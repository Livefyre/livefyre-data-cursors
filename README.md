# Livefyre-Timeline.js

A JavaScript library you can use to access Livefyre Personal Streams data and model common timeline consumption patterns.

This library is intended to be usable in both node.js and the brower (via browserify).

## Examples

There are some included examples of how to build timeline visualizations with this library. Serve them with `make browser && make server`:

* [public/demos/simple-pager.html](./public/demos/simple-pager.html) - Render a simple Timeline visualization using React.

## Usage

```javascript
// Create a Connection to Livefyre
var createLivefyreConnectionFactory = require('livefyre-timeline-service/backends/factory');
var connectionFactory = createLivefyreConnectionFactory(
  'qa|uat|production',
  {
    token: "LFTOKEN_OF_USER"
  }
);
var chronosConnection = connectionFactory.chronos();

// We now have a Connection. But what do we want to get from the other side?
// Let's create a Query to describe what we want.
var RecentQuery = require('livefyre-timeline-service/backends/chronos/cursors').RecentQuery;
var topic = "urn:livefyre:studio-qa-1.fyre.co:user=TEMP-671eb61404581b08:alertStream";
// We want recent items related to that topci
var recentAlertsQuery = RecentQuery(topic);

// Now we can get a Cursor object that will let us retrieve the results of our
// Query over the Connection
// A Cursor represents your position in reading through the results of your Query.
var SimplePager = require('livefyre-timeline-service/models/simple').SimplePager;
var recentAlertsCursor = chronosConnection.openCursor(recentAlertsQuery);
var recentAlertsPager = new SimplePager(recentAlertsCursor);

// We can use the Pager to page through the results using the cursor
var alerts = [];
recentAlertsPager
  .on('readable', function () {
    var data = this.read();
    alerts = alerts.concat(data);
    render(alerts);
    // If there is a next page of data on the server...
    if (this.count().estimated) {
      // load it
      this.loadNext()
    }
  })
  .on('error', console.error.bind(console))
  .on('end', console.log.bind(console, 'all done'))

function render(alerts) {
  console.log("Alerts list is now: ", alerts.join(', '))
}
```

## Make targets

* `make browser` - Browserify the library, creating `./dist/livefyre-timeline.js`. You can verify the build works using `./public/test-dist-html`.
