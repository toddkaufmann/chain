#!/usr/bin/env ruby
require 'open-uri'
CHECK_GLOBAL_LINKS = false

# 1. Get all links
# 2. For each link, check if it's good:
#   a. If it's local anchor, check if it's in the list of anchors.
#   b. If it's local file, fetch that file and check if it's in that file's anchors.
#   c. If it's global URL, fetch URL to see if it's not 404 and well-formed.

def main
  dataset = {}
  Dir["*.md"].each do |file|
    puts "Collecting links and anchors from #{file}..."
    collect_links_and_anchors(file, dataset)
    puts "Checking links in #{file}..."
    check_links(file, dataset[file][:links], dataset)
  end
end

def collect_links_and_anchors(fp, dataset={})
  f = nil
  dataset[fp] ||= {links:nil, anchors:nil}
  ds = dataset[fp]
  ds[:links] ||= begin
    f ||= File.read(fp)
    links = []
    f.scan(%r{\[([^\]]*)\]\(([^\)]*)\)}m).each do |pair|
      links << pair
    end
  end
  ds[:anchors] ||= begin
    f ||= File.read(fp)
    extract_anchors(f)
  end
end

def check_links(file, links, dataset = {})
  dataset["__checked_remote_urls"] ||= {}
  cache = dataset["__checked_remote_urls"]
  links.each do |(name, ref)|
    if ref[0,1] == "#"
      if !dataset[file][:anchors].include?(ref)
        puts "! Broken anchor link in file #{file}: [#{name}](#{ref})"
      end
    elsif ref =~ %r{^https?://}
      if !cache[ref]
        if !check_url(ref)
          puts "! Broken global link in file #{file}: [#{name}](#{ref})"
          cache[ref] = "failed"
        else
          cache[ref] = "ok"
        end
      end
    else # cross-file link
      ref = ref.sub(%r{^\./},"")
      fn, anchor = ref.split("#")
      anchor = "##{anchor}" if anchor
      if !check_url(fn)
        puts "! Broken local link in file #{file}: [#{name}](#{ref})"
      elsif anchor
        collect_links_and_anchors(fn, dataset)
        check_links(fn, [[name + " (from #{file})", anchor]], dataset)
      end
    end
  end
end

def check_url(url)
  if url == "https://dx.doi.org/10.6028/NIST.FIPS.202"
    return true
  elsif !CHECK_GLOBAL_LINKS && url =~ /^https?:/
    return true
  else
    x = open(url).read rescue nil
    !!x
  end
end

def extract_anchors(data)
  results = [] # list of anchors
  data.split("\n").each do |line|
    if h = extract_heading(line)
      depth, title, anchor = h
      results << anchor
    end
  end
  results
end

# Returns `nil` or `[depth, title, anchor]`
def extract_heading(line)
  if line =~ /^(#+)\s(.*)/
    prefix = $1
    title = $2
    depth = prefix.size
    anchor = "#" + title.downcase.gsub(/\W+/,"-").gsub(/(\d)\-(\d)/,"\\1\\2")
    [depth, title, anchor]
  end  
end

main