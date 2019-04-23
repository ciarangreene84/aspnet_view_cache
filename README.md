# ASP.NET View Caching

ASP.NET Caching was introduced in ASP.NET 2.0. See https://docs.microsoft.com/en-us/aspnet/web-forms/overview/data-access/caching-data/using-sql-cache-dependencies-cs

A problem that it addressed was how to expire the cache. SqlCacheDependency was introduced.

## SqlCacheDependency

This is the cache expiration mechanism. In brief:
1. A trigger is added on INSERT, UPDATE and DELETE on the table of interest.
2. This trigger will update a notification table in the database whenever a record on the table of interest is INSERTED/UPDATED/DELETED.
3. The application will poll the notification table to understand whether a table has changed since data was last cached from it.
4. If the application detects a change, it will expire the cached data and the data will be reloaded whenever the application next requires it.

This mechanism is not without limitations... for example, the polling frequency. If the frequency is too low (e.g. 30 minutes), then changes to the data will not be picked up. Broadly speaking, where there is data that changes very infrequently (consider a Products table) this is a good mechanism.

## The Problem

What if one wants to use the above caching mechanism for a database View? Any table involved in the View may change independently of the other. Therefore, it is necessary to expire the cache should *any* of the underlying tables change.

This was not built into the mechanism, i.e. no support for Views in the manner mentioned above.

## The Solution

To enable ASP.NET caching on a database, the aspnet_regsql.exe command line tool is used. This creates the notification table in the target database as well as a number of stored procedures.

The stored procedures are what's used by an application to enable caching.

The solution to enable View caching was to tinker with these stored procedures. Very simply, rather than throwing an error if the application tried to create a cache notification on a view (original behaviour), the behaviour was changed to loop through all of the tables involved in the view and creates the triggers on each. This then feeds back into the rest of the mechanism.

## Note

The above solution to the problem is fairly simple *BUT* this wasn't built into the 'out of the box' mechanism. There are reasons why this *shouldn't* be done.

For example, consider a view made of ten tables... These tables may be changing independently and frequently. Therefore the cache may be constantly expiring.

What if a view changes and a new table is included? The cache may not get expired unless the stored procedure is re-run. Will people remember that?

Any additional operation costs. Adding triggers adds operations. 

On the whole, this mechanism has been useful, *but* it must be stressed that there are considerations when enabling View caching and these require careful thought.



