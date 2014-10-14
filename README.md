uffda [![Build Status](https://travis-ci.org/tigertext/uffda.svg)](https://travis-ci.org/tigertext/uffda)
=======================================================================================================

An Erlang Service Registry used to track the availability and status of services conforming to its interface. 
From Wikipedia, "Uff da is often used in the Pacific Northwest and Upper Midwest as a term for sensory overload. It can be used as an expression of surprise, astonishment, exhaustion, relief and sometimes dismay. For many, Uff da is an all-purpose expression with a variety of nuances, and covering a variety of situations." The name was chosen to reflect the feelings that may result from service outages, and hopefully this project will provide insight to better track outages and presence of services.

Testing
-------

In order to run tests, clone and hit make:

    $ git clone https://github.com/pierce-m/uffda
    $ cd uffda
    $ make tests

To check that the types are properly specified, make the plt and run dialyzer:

    $ make plt
    $ make dialyze

Querying Uffda
--------------
To get a list of services, call `uffda_client:which_services/0`. To get the
status of a particular service, `uffda_client:service_status/1`. You can also
query over HTTP, with `GET /services` to provide the list of services and `GET
/services/:service_name` to provide the current status of the corresponding
service.

Using Uffda to watch a particular service
-----------------------------------
Uffda has an architecture that expects interaction from the service when things
are smoothly sailing, and will take reporting into it's own hands with timeouts
and monitors when things aren't working out. Currently it runs on *per-node*
basis, distributed uffda is on the roadmap.

In the normal pattern of starting up,`uffda_client:register_service/1` is
called at the earliest possible point to enter the registry. Recommendations
would be in either `$service:start/0` before `application:start/1` is called or
as part of the `erl` command line args with `-s uffda_client register_service
$service` before `-s $service`.

Next would be `uffda_client:starting_service/{1,2}`, which indicates that the
startup sequence has initiated and creates a monitor that lets uffda watch for
the service going down.  Suggested callpoint would be in the `$service:start/2`
callback for `application`, i.e. once the services code has begun executing.

To indicate that startup has completed successfully, calling
`uffda_client:set_service_online/1` is expected. If the timeout is reached
before this is called, the internal state will move to `slow_start`, but will
transition to `up` if it is called eventually.

If the service has to voluntarily go down, the function
`uffda_client:set_service_offline/1` will move the internal state to `down`.
Alternatively, if the service's process (the pid that has called
`starting_service/1` or the second argument to `starting_service/2`) exits the
monitor will transition the state accordingly. If the Reason for the monitor
`'DOWN'` message to fire is `normal`, the fsm will move to `down` otherwise to
`crashed`.

When the service tries to right itself again with another call to starting
service, the internal state will be `restarting`, and similarly if it times out
it will be `slow_restarting`.

Web API
-------
Uffda has a RESTful API to facilitate a standard method of external communication.
As noted above, queries can be done with `GET /services[/:name]` to either get
all services or the status of the one specified by `:name`. To create a service,
execute `PUT /services/:name`. To change the status of a service, `POST 

Publish & Subscribe
-------------------
Uffda has support for subscribing to particular services and receiving
notifications over several mediums when state changes for those services. To
subscribe to an SSE stream, hit the endpoint `/subscribe/:service_name` with an
HTTP request.

[![Imgur](http://i.imgur.com/VR2al8I.png)](http://i.imgur.com/VR2al8I)

The erlang shell commands emulate the behavior of a service making those calls
to uffda, and the SSE stream reports on the changes in subscription or of the
subscribed to service. The current format for SSE is that the `event` value is
a member of `{subscription_starting, updating, unsubscribing}`, `id`'s value is
the service name, and `data` encodes the most recent state of the service. 

The syndication is not limited to SSE: currently there is also support for SMS,
email, sending to another process, in addition to being extensible. There is a
behaviour in place that dictates how to create a sender, which expects a `send`
callback with the following signature.

    send(atom(), #ass{address :: pid() | string(),
                      service :: atom(),
                      status :: atom()) -> ok.
    
Such a callback is expected to be defined with the behaviour `uffda_publisher`
declared. An example for sending emails with the unix `mail` command is shown below:

[![Imgur](http://i.imgur.com/JoeRXub.png)](http://imgur.com/JoeRXub)

There is also a need to edit the `find_vars` function in `src/pubsub/uffda_subscription.erl`
to accomodate further behaviours.
Further ideas for creating senders would be

+ TigerText
+ Sensu
+ Filtering on the event type, e.g. sending only on a timeout or a crash.

Additional room for improvement would be

+ reading a list of subscribers from a static file:

        {email, "tholland@tigertext.com", baz}.
        {sms, "9178576309", baz}.
        {sms, "5559991234", bar}.

+ Subscriptions added/revoked over HTTP

Contributing
------------
Pull requests are welcome, but please correct any dialyzer errors or failing test cases
before expecting a merge.
