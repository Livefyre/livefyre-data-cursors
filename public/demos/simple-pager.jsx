var MockChronosConnection = LivefyreDataCursors.backends.chronos.connection.MockConnection;
var Precondition = LivefyreDataCursors.Precondition;
var RecentQuery = LivefyreDataCursors.backends.chronos.cursors.RecentQuery;
var SimplePager = LivefyreDataCursors.models.simple.SimplePager;
var ReactCSSTransitionGroup = React.addons.CSSTransitionGroup;

var ReverseStreamComponent = React.createClass({
    getInitialState: function () {
        var cursor = this.props.client.openCursor(this.props.query);
        var pager = new SimplePager(cursor, {autoLoad: false});
        pager.on('readable', this.onReadable.bind(this));
        pager.on('error', function (event) {
            console.log('error', event);
        });
        pager.on('initialized', function (event) {
            console.log("initialized");
        });

        pager.on('end', function () {
            console.log("pager issued end");
            this.setState({done: true, estimated: false});
        }.bind(this));

        return {
            cursor: cursor,
            pager: pager,
            items: [],
            count: undefined,
            estimated: true,
            done: false,
            seen: {}
        }
    },

    onReadable: function (event) {
        console.log("readable:", event);
        var pager = this.state.pager;
        var data = pager.read({loadOnFault: false});
        var new_items = this.state.items;
        var seen = this.state.seen;
        if (Array.isArray(data)) {
            console.log("read:", data.length);
            data.map(function (item) {
                console.log("" + item.tuuid + ": " + item.verb + ", " + item.published);
                if (seen[item.tuuid]) {
                    console.log("duplicate!");
                    return;
                }
                seen[item.tuuid] = true;
                new_items.push(item);
            });
        } else {
            console.log("unexpected; data is:", data);
        }
        if (pager.done()) {
            console.log("we're at the end of the stream", pager.done(), pager.cursor.hasNext());
        }

        this.setState({
            items: new_items,
            estimated: !pager.done(),
            count: new_items.length,
            done: pager.done()
        });
    },

    loadMore: function () {
        this.state.pager.loadNextPage();
    },

    renderItem: function (item) {
        return (<this.props.itemComponent item={item} key={item.tuuid} />);
    },

    render: function () {
        var more = this.state.estimated ? (<button onClick={this.loadMore}>Load more</button>) : "";
        var plus = this.state.estimated ? '+' : '';
        return (
            <div>
                <h2>Item Count: {this.state.count}{plus}</h2>
                <ReactCSSTransitionGroup transitionName="newActivity">
                    {this.state.items.map(function (item) {
                        return this.renderItem(item);
                    }.bind(this))}
                </ReactCSSTransitionGroup>
                {more}
            </div>
        );
    }
});


var AlertActivityItem = React.createClass({
    render: function () {
        var i = this.props.item;
        var who = i.actor.handle || i.actor.displayName;
        var verb = i.verb == 'post' ? 'replied' : i.verb;
        var where = i.target.title;
        var what = i.object.content;
        var original = i.verb == 'like' ? i.object.content : i.object.inReplyTo.content;
        var when = i.published;
        return (
            <div>
                <hr />
                <span>Your post in {where}</span>:
                <div dangerouslySetInnerHTML={{__html: original}}></div>
                <span>{who} {verb} @ <i>{when}</i></span>
            </div>
        );
    }
});
