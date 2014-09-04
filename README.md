uffda
=====

An Erlang Service Registry used to track the availability and status of services conforming to its interface. 
From Wikipedia, "Uff da is often used in the Pacific Northwest and Upper Midwest as a term for sensory overload. It can be used as an expression of surprise, astonishment, exhaustion, relief and sometimes dismay. For many, Uff da is an all-purpose expression with a variety of nuances, and covering a variety of situations." The name was chosen to reflect the feelings that may result from service outages, and hopefully this project will provide insight to better track outages and presence of services.

Testing
-------
In order to run it locally:

    $ git clone https://github.com/pierce-m/uffda
    $ cd uffda
    $ make

To check that the types are properly specified, run 

    $ make dialyze
