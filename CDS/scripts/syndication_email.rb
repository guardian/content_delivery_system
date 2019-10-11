#!/usr/bin/env ruby

#This method sends a nicely formatted, brand-aware email providing information on a recently syndicated email.
#
#Arguments:
#  <vidispine_host>blah - Host to communicate with Vidispine on
#  <vidispine_port>nnnn [OPTIONAL] - port that vidispine is present on.  If not present or invalid, will default to port 8080.

require 'CDS/Datastore'
require 'net/http'
require 'mail'
require 'Vidispine/VSMetadataElements.rb'
require 'awesome_print'
require 'pathname'
puts "Starting e-mail programme"

$store = Datastore.new('syndication_email')

vidispine_server = $store.substitute_string(ENV['vidispine_host'])
vidispine_port = 8080
if ENV['vidispine_port']
    begin
      vidispine_port=int($store.substitute_string(ENV['vidispine_port']))
    rescue Exception=>e
      puts "-WARNING: #{e.message}. Using default port value of 8080"
    end
end
username = $store.substitute_string(ENV['vidispine_user'])
passwd = $store.substitute_string(ENV['vidispine_passwd'])


thumbnail_path = $store.substitute_string(ENV['thumbnail'])

thumbnails = thumbnail_path.split('|')


#thumbnail_url = URI("http://#{vidispine_server}:#{vidispine_port}#{thumbnail_path}")
#puts "DEBUG: thumbnail url is #{thumbnail_url.to_s}"
#content = Net::HTTP.get(thumbnail_url)
puts "DEBUG: thumbnail path is #{thumbnail_path}"

begin
  if thumbnails[0] != ""
    content = File.read(thumbnails[0])
  else
	  content = File.read(thumbnails[1])
  end
rescue Exception=>e
  puts "-ERROR: #{e.message}. Thumbnail data not present so exiting."
  abort("Thumbnail data not present so exiting.")
end

#content = File.read(thumbnail_path)

recipients = $store.substitute_string(ENV['recipients'])

rr = recipients.gsub '|', ', '

bcc_recipients = $store.substitute_string(ENV['bcc_recipients'])

bccrr = bcc_recipients.gsub '|', ', '

cc_recipients = $store.substitute_string(ENV['cc_recipients'])

ccrr = cc_recipients.gsub '|', ', '

input_labels = $store.substitute_string(ENV['labels'])

ready_labels = input_labels.split('|')

input_fields = $store.substitute_string(ENV['fields'])

ready_fields = input_fields.split('|')

html_field_data = ''

text_field_data = ''

ready_labels.zip(ready_fields).each do |label, field|
    html_field_data = html_field_data + "<tr><td align=\"right\" valign=\"top\" style=\"padding-top:8px;padding-bottom:8px;padding-right:8px;\"><font face=\"Arial,Helvetica,sans-serif\" size=\"3\" color=\"#000000\">#{label}:</font></td><td style=\"padding-top:8px;padding-bottom:8px;\"><font face=\"Arial,Helvetica,sans-serif\" size=\"3\" color=\"#000000\">#{field}</font></td></tr>"
    text_field_data = text_field_data + "#{label}: #{field}
"
end

# incluse this in XML for time format %T %d/%m/%Y

#pt = DateTime.strptime($store.substitute_string(ENV['pub_time']), '%Y-%m-%dT%H:%M:%SZ')

if $store.substitute_string(ENV['pub_time']) != ""
	pt = DateTime.parse($store.substitute_string(ENV['pub_time']))
else
	pt = DateTime.now
end

$store.substitute_string(ENV['time_format'])

rpt = pt.strftime($store.substitute_string(ENV['time_format']))

if rpt.include? " 0"
  rpt = rpt.gsub! ' 0', ' '
end

if rpt.include? " 0"
  rpt = rpt.gsub! '/0', '/'
end

isecs1 = $store.substitute_string(ENV['duration']).to_f

isecs = isecs1.to_i

dur = Time.at(isecs).utc.strftime("%H:%M:%S")

if dur[0,2] == '00'
    if dur[3,2] == '00'
        fs = dur[6,2]
        fs = fs.to_i
        duration = fs.to_s + " seconds"
    else
        fm = dur[3,2]
        fm = fm.to_i
        fs = dur[6,2]
        fs = fs.to_i
        duration = fm.to_s + " minutes and " + fs.to_s + " seconds"
    end
else
    fh = dur[0,2]
    fh = fh.to_i
    fm = dur[3,2]
    fm = fm.to_i
    fs = dur[6,2]
    fs = fs.to_i
    duration = fh.to_s + " hours, " + fm.to_s + " minutes, and " + fs.to_s + " seconds"
end

uploadp = Array.new

if $store.substitute_string(ENV['website_us']) == 'Upload Succeeded' || $store.substitute_string(ENV['website_us']) == 'Ready to Upload'
    uploadp.push('Website')
end

if $store.substitute_string(ENV['facebook_us']) == 'Upload Succeeded' || $store.substitute_string(ENV['facebook_us']) == 'Ready to Upload'
    uploadp.push('Facebook')
end

if $store.substitute_string(ENV['youtube_us']) == 'Upload Succeeded' || $store.substitute_string(ENV['youtube_us']) == 'Ready to Upload'
    uploadp.push('YouTube')
end

if $store.substitute_string(ENV['dailymotion_us']) == 'Upload Succeeded' || $store.substitute_string(ENV['dailymotion_us']) == 'Ready to Upload'
    uploadp.push('DailyMotion')
end

if $store.substitute_string(ENV['spotify_us']) == 'Upload Succeeded' || $store.substitute_string(ENV['spotify_us']) == 'Ready to Upload'
    uploadp.push('Spotify')
end

if $store.substitute_string(ENV['mainstream_us']) == 'Upload Succeeded' || $store.substitute_string(ENV['mainstream_us']) == 'Ready to Upload'
    uploadp.push('Mainstream Syndication')
end

uploadpr = uploadp.join(', ')

tags = $store.substitute_string(ENV['tags']).gsub('|',', ')

if tags[-2, 2] == ', '
    tags = tags.chop.chop
end

el = VSMetadataElements.new(vidispine_server,vidispine_port,username,passwd)

wg = 'n/a'

el.findUUID($store.substitute_string(ENV['working_group'])) do |entry|
  puts entry.name
  puts entry.uuid
  entry.each do |item,values|
    puts item
    puts values
    wg = values
  end
end

html_code = "<table width=\"688\" cellspacing=\"0\" bgcolor=\"#ffffff\">
    <tr bgcolor=\"#005689\">
        <td style=\"padding:10px;\">
            <font face=\"Georgia,serif\" size=\"4\" color=\"#ffffff\">
                GNM Syndication: New Video Details
            </font>
        </td>
        <td align=\"right\" style=\"padding:10px;padding-right:30px;\">
            <img src=\"cid:roundimage@dc1-workflow-02.mail\">
        </td>
    </tr>
</table>
<table width=\"688\" cellspacing=\"0\" bgcolor=\"#ffffff\">
    <tr valign=\"top\">
        <td rowspan=\"2\" width=\"250\">
            <img src=\"cid:tnimage@dc1-workflow-02.mail\">
        </td>
        <td width=\"140\" height=\"64\" align=\"right\" style=\"padding-right:8px;\" valign=\"bottom\">
            <font face=\"Arial,Helvetica,sans-serif\" size=\"3\" color=\"#000000\">
                Publication Time:
            </font>
        </td>
        <td valign=\"bottom\">
            <font face=\"Arial,Helvetica,sans-serif\" size=\"3\" color=\"#000000\">
                #{rpt}
            </font>
        </td>
    </tr>
    <tr>
        <td width=\"140\" align=\"right\" style=\"padding-right:8px;padding-top:8px;\" valign=\"top\">
            <font face=\"Arial,Helvetica,sans-serif\" size=\"3\" color=\"#000000\">
                Duration:
            </font>
        </td>
        <td valign=\"top\" style=\"padding-top:8px;\">
            <font face=\"Arial,Helvetica,sans-serif\" size=\"3\" color=\"#000000\">
                #{duration}
            </font>
        </td>
    </tr>
</table>
<table width=\"688\" cellspacing=\"0\" bgcolor=\"#ffffff\">
    <tr>
        <td width=\"140\" align=\"right\" style=\"padding-top:8px;padding-bottom:8px;padding-right:8px;\" valign=\"top\">
            <font face=\"Arial,Helvetica,sans-serif\" size=\"3\" color=\"#000000\">
                <strong>Title:</strong>
            </font>
        </td>
        <td style=\"padding-top:8px;padding-bottom:8px;\">
            <font face=\"Arial,Helvetica,sans-serif\" size=\"3\" color=\"#000000\">
                <strong>#{$store.substitute_string(ENV['title'])}</strong>
            </font>
        </td>
    </tr>
    <tr>
        <td align=\"right\" style=\"padding-top:8px;padding-bottom:8px;padding-right:8px;\" valign=\"top\">
            <font face=\"Arial,Helvetica,sans-serif\" size=\"3\" color=\"#000000\">
                Platforms:
            </font>
        </td>
        <td style=\"padding-top:8px;padding-bottom:8px;\">
            <font face=\"Arial,Helvetica,sans-serif\" size=\"3\" color=\"#000000\">
                #{uploadpr}
            </font>
        </td>
    </tr>
    <tr>
        <td valign=\"top\" align=\"right\" style=\"padding-top:8px;padding-bottom:8px;padding-right:8px;\">
            <font face=\"Arial,Helvetica,sans-serif\" size=\"3\" color=\"#000000\">
                Working Group:
            </font>
        </td>
        <td style=\"padding-top:8px;padding-bottom:8px;\">
            <font face=\"Arial,Helvetica,sans-serif\" size=\"3\" color=\"#000000\">
                #{wg}
            </font>
        </td>
    </tr>
    <tr>
        <td valign=\"top\" align=\"right\" style=\"padding-top:8px;padding-bottom:8px;padding-right:8px;\">
            <font face=\"Arial,Helvetica,sans-serif\" size=\"3\" color=\"#000000\">
                Tags:
            </font>
        </td>
        <td style=\"padding-top:8px;padding-bottom:8px;\">
            <font face=\"Arial,Helvetica,sans-serif\" size=\"3\" color=\"#000000\">
                #{tags}
            </font>
        </td>
    </tr>
    #{html_field_data}
</table>
<table width=\"688\" cellspacing=\"0\" bgcolor=\"#ffffff\">
    <tr>
        <td valign=\"top\" align=\"right\" style=\"padding:10px;\">
            <img src=\"cid:logo@dc1-workflow-02.mail\">
        </td>
    </tr>
    <tr>
        <td align=\"center\">
            <font face=\"Arial,Helvetica,sans-serif\" size=\"2\" color=\"#000000\">
                Guardian News &amp; Media Limited - a member of Guardian Media Group PLC
                <br />
                Registered Office: Kings Place, 90 York Way, London, N1 9GU. Registered in England No. 908396
            </font>
        </td>
    </tr>
</table>"

plain_text = "GNM Syndication: New Video Details

Title: #{$store.substitute_string(ENV['title'])}
Publication Time: #{rpt}
Duration: #{duration}
Platforms: #{uploadpr}
Working Group: #{wg}
Tags: #{tags}
#{text_field_data}

Guardian News & Media Limited - a member of Guardian Media Group PLC
Registered Office: Kings Place, 90 York Way, London, N1 9GU. Registered in England No. 908396"

st = $store.substitute_string(ENV['subject']) + $store.substitute_string(ENV['title'])

mail=Mail.new do
    to      rr
    cc      ccrr
    bcc     bccrr
    from    $store.substitute_string(ENV['from'])
    subject st
    delivery_method :smtp, address: $store.substitute_string(ENV['smtp_server']), port: 25
    content_type 'multipart/related'
    @bodypart = Mail::Part.new do
        text_part do
            body plain_text
        end
        html_part do
            content_type 'text/html; charset=UTF-8'
            body html_code
        end
    end
    add_part @bodypart
end

image_base_path = Pathname.new($store.substitute_string(ENV['image_path']))

begin
    mail.attachments['round.gif'] = {:content_id=>'<roundimage@dc1-workflow-02.mail>',:content=>File.read(image_base_path + 'round.gif')}
rescue Errno::ENOENT=>e
    puts "-WARNING: Unable to attach file to email: #{e.message}"
end
begin
    mail.attachments['g.png'] = {:content_id=>'<logo@dc1-workflow-02.mail>',:content=>File.read(image_base_path + 'g.png')}
rescue Errno::ENOENT=>e
    puts "-WARNING: Unable to attach file to email: #{e.message}"
end

mail.attachments['thumbnail.jpg'] = {:content_id=>'<tnimage@dc1-workflow-02.mail>',:content=>content}
mail.deliver
puts mail.to_s #=>
