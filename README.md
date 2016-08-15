What Is the Content Delivery System?
======

The CDS is a generic way to get media and metadata from one place to another.
This is necessary at many points in the Multimedia production system:

[MM production system 'bubble diagram']

Each of the arrows in the diagram above corresponds a process which, in general, will involve retrieving media and metadata from one place, converting their formats into another format, and putting the end result somewhere else.

When the system was first put together, these operations were achieved by using a large number of bespoke shell scripts running on a Multimedia server.  Each had their own configurations, logfiles, foibles and bugs with the end result that even relatively simple procedures like inputting media from a video newswire service could become a major headache if there were any technical faults.

Individually written code, however, is not really necessary to perform these functions.  Most of the code in these operations is exactly the same - it's just a case of changing the server it's talking to, or the XML template, or a mapping configuration.

The CDS came out of a desire to simplify this tangled system, and make it possible for a non-coder to administer and perform day to day debugging and maintenance on the system - something that was not possible before.

How do I install it?
-----

1. Check out this repository
2. run sudo ./install.sh (on Mac or Linux)
3. this will install prerequisites (using apt, yum or port if available) and install to /usr/local/lib/cds_backend, /etc/, /usr/local/bin etc.  Consult the top of of install.sh to see exactly where stuff is installed.

How do I run it?
------

See below! But, in a nutshell......
$ cds_run.pl --route {routename_no_path} [--input-inmeta /path/to/metadata/if/applicable]

Where are the logs?
------

In /var/log/cds_backend/{routename}.

Can I ship logging elsewhere?
------

You could use something like logstash to do this, or you could read DBLOGGING.txt to log out to a database.  cloudworkflowserver and internalworkflow have dashboards built to read this information.

Understanding CDS
============

The Route File
-----

The route file is a core concept in CDS.  It is an XML file which describes the exact operations that must be undertaken to fulfill one of the arrows in the diagram above.  Here is a real example from the system.

    <?xml version="1.0" ?>
    <route name="Reuters WNE (Packaged)" type="active">
        <input-method name="ftp_pull_difference">
                <host>input.server.name</host>
                <username>anonymous</username>
                <password>myuser@myhostname</password>
                <remote-path>/Video</remote-path>
                <cache-path>/data/Raw Agency Feeds/Reuters WNE (Packaged)</cache-path>
                <!-- this file list is persistent, and shows the previous state of the ftp server -->
                <old-file-list>/var/spool/cds_backend/reuters_ftp/previous_file_list</old-file-list>
                <!-- this file list is transient, and shows both that the process is currently running and the
                current state of the ftp server -->
                <new-file-list>/var/spool/cds_backend/reuters_ftp/new_file_list</new-file-list>
                <keep-original />
        </input-method>
    
    <process-method name="check_files">
        <take-files>media|xml</take-files>
    </process-method>

    
    <process-method name="engine_transcode">
        <take-files>media</take-files>
        <output-profile>Reuters WNE (Packaged)</output-profile>
        <warn-time>400</warn-time>
        <fail-time>900</fail-time>
    </process-method>

    <process-method name="check_files">
        <take-files>media</take-files>
    </process-method>

    <output-method name="archive_to_san">
        <take-files>media</take-files>
        <archive-path>/data/Incoming/Feeds/REUTERS/INGEST_MEDIA_REUTERS</archive-path>
    </output-method>
    
    <process-method name="check_files">
        <take-files>xml</take-files>
    </process-method>

    <!--upload XML metadata to FIPS to appear on wires.dmz.gnl-->
    <output-method name="ftp">
        <take-files>xml</take-files>
        <hostname>server.interested.in.xml</hostname>
        <username>username</username>
        <password>passwd</password>
        <remote-path>/path/to/storage</remote-path>
    </output-method>

    <output-method name="archive_to_san">
        <take-files>xml</take-files>
        <archive-path>/data/Incoming/Feeds/REUTERS/INGEST_META_REUTERS</archive-path>
    </output-method>
    </route>


This file lives, along with all of the other route files, in /etc/cds_backend/routes.
In essence, it forms a kind of script that is run through the cds_run command:

    cds_run --route "Reuters WNE (Packaged).xml"


In practice, this is run every few minutes by the cron system on the server (consult the CronniX documentation for more details on this).

As you can see, the route file contains every piece of configuration pertinent to this specific operation.  This includes hostnames, usernames, cache paths, etc.
In general, it should be possible to read through the route file and see immediately what operations are taking place at each stage.

All of the process elements are referred to as "methods" (there is more detail on these in the section "Under the Hood").  There are a number of method types that the CDS understands:

- **input-method** - these is used in the initial input, read-in and setup stages of the route
- **process-method** - these are typically used in the "working" stages of transcoding and transforming
- **output-method** - these are used to send or store the results of the processing stages somewhere
- **success-method** - these are run once the entire route has succeeded, typically used to update logs or database entries or generate reports.  A failure at this stage will not stop the route from completing, as by definition it has succeeded by this point
- **fail-method** - these are run if the entire route has failed, typically used to propagate error messages or update database entries.  Since the route has already failed, a failure within a fail-method will not prevent further fail-methods from running.

To summarise the contents of the route:
This route is for handling material from the Reuters WNE service, which comes as discrete packages (you can see this in the <route name="blah"> part)
We log into the given FTP server and download anything that has newly appeared.  The system knows what was there before by checking the file /var/spool/cds_backend/reuters_ftp/previous_file_list.
Files are downloaded into /data/Raw Agency Feeds/Reuters WNE (Packaged) locally, from the path /Video on the server and are not deleted from the server (a delete attempt would fail anyway, as we don't have write-access, so we tell the system not to try in order to avoid error messaes)
Each download is then checked that both the media and XML files have correctly arrived.

The media file is converted using Episode Engine (engine_transcode) - see the Digital Audio/Video Engineering section for more details about transcoding processes.  There is a specific "profile" (collection of settings) configured in Episode Engine to handle this media which is called Reuters WNE (Packaged).  The operation will fail if the system has to wait more than 900s for the file to arrive.
Once the encoding is complete, we check that the media file actually exists.  This has the added benefit of logging the current media file name (see "Logging", later on)
We then move the correctly transcoded file into a folder that is watched by Final Cut Server (FCS).  This triggers FCS's ingest process (see seperate documentation for more details on this).
We then upload the XML metadata file that we have received into the FIPS system so that it can be seen in the regular newswire browser system
Finally we output the XML metadata file into another location, from where it will be picked up by the Media Pump system as a part of Final Cut Server's ingest process (documented seperately)
If you follow these steps through the XML above, it should all make sense.  This XML effectively forms a script that directly tells the system how to ingest this media.

There are many other examples of route files within the system, some considerably more complex than this.

File Bundles
-----

CDS deals with a strictly defined set of up to four files, which you can see referenced in the <take-file> lines above.  These four types are defined as:

- **XML** file - a generic metadata format, often not intended to be read by the CDS route itself.  Typically have the extension "XML", but this designation is also used for some trigger files (see "Inter-Route Communication" in "Advanced Topics")
- **meta** file - a specific metadata format, that is defined by Episode Engine.  These are XML-format files that are output by Episode Engine, containing a freely definable section that we use for storing all our system metadata and a constructed section where Episode describes the file that it has output.  These are intended to be read and used within the CDS system.  See "Handling Metadata" later on for more details on this
- **inmeta** file - a very similar format that is also defined by Episode Engine.  These are XML-format files which are understood as input by Episode Engine and which are also used as triggers for upload routes in the system
- **media** file - a generic file type that represents the actual "thing" being sent.

Subtleties
-----

The route file is intended to be as simple as possible to read.  There are therefore some hidden subtleties to the way that this is processed.

In the above example, the FTP server can have any number of media files and XML files all jumbled up.  So how does it handle more than one file coming in?
The input-method, in this case ftp_pull_difference, is responsible for creating the file bundles (media file/XML file/inmeta file etc.)
It does this by recognising the base part of the filename, i.e. for a media file called myvideo.mp4 the associated XML file should be either myvideo.mp4.xml or myvideo.xml.

Any input-method that can return more than one set of files can tell the cds_run process to enter "batch mode".  This means that every process and output method is run once for every file set downloaded.  In this case, if four pieces of media were downloaded from the server, then each process-method and output-method is run for every piece of media.
This makes more sense when you see the log file (see "Common Logging", below)

Error Handling
----

Any of the methods above can fail for a multitude of reasons.

If this happens, then the method should output a line to the log, stating -ERROR: {description of the error} and then exit and signify to cds_run that it has failed.

cds_run will then note that the route has failed and run the fail-method scripts before exiting.  However, if the step concerned is not vital to the route succeeding (e.g., a logging stage), you can set a flag called <non-fatal/> anywhere in the method configuration (i.e., between the <{type}-method name=""> and </{type}-method> lines).  cds_run will also pick up the error message and pass this on to any fail-methods, where it will be available as a string substitution (see "Handling Metadata" for more details on string substitutions).

A typical use for a fail-method is to send out an email to inform technical support that something has gone wrong.

Common Logging
------

The most important thing when it comes to trying to debug a problematic route is a specific place and a rigid format for all logging relating to that route.

CDS logs can all be found in the Console, under /var/log -> cds_backend.  There are then subtrees for each route, and a seperate logfile for each run of the route, labelled with the route name and the time/date at which the run started.
Additionally, the system can be configured to send logs to an SQL or ElasticSearch server, from where they can be read by a web app.
