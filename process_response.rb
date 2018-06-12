# Processes the response

require 'yaml'
require 'date'

# If we have a response file, use that

module H
  def sym_with_underscore_to_camel_case(sym)
    mapped = sym.to_s.gsub(/_(.)/) { Regexp.last_match[1].upcase }
    # puts "#{sym.to_s} mapped to actual key #{mapped}"
    mapped
  end
  
  def method_missing(sym, *args, &blk)
    new_name = sym_with_underscore_to_camel_case(sym)
    r = fetch(new_name) { fetch(new_name) { super } }
    Hash === r ? r.extend(H) : r
  end
end

datafile = File.join(File.dirname(__FILE__), 'github_graphql_responses', 'response.yml')

branches =
  YAML.load_file(datafile).
  map { |b| b.extend(H) }


puts branches.size()


def age(s)
  d = Date.strptime(get_yyyymmdd(s), "%Y-%m-%d")
  age = (Date::today - d).to_i
end

def get_yyyymmdd(s)
  s.match(/(\d{4}-\d{2}-\d{2})/)[1]
end

def get_pending_reviews(requests)
  # puts "REQ: #{requests}"
  requests.map { |r| r.extend(H).requested_reviewer.extend(H) }.map do |r|
    {
      status: 'PENDING',
      reviewer: r.name,
      date: nil,
      age: nil
    }
  end
end

# GitHub can return multiple reviews for the same person in some cases -
# e.g., a person first declines a PR, and then later approves it.
# For each user, get the latest one only.
def get_reviews(reviews)
  all_revs = reviews.map { |r| r.extend(H) }.map do |r|
    {
      status: r.state,
      reviewer: r.author.login,
      date: get_yyyymmdd(r.updated_at),
      age: age(r.updated_at)
    }
  end.map { |r| r.extend(H) }
  revs_by_person = all_revs.group_by { |r| r[:reviewer] }.values
  latest_revs = revs_by_person.map do |persons_reviews|
    persons_reviews.sort { |a, b| a[:date] <=> b[:date] }[-1]
  end

  # if (latest_revs.size() != all_revs.size) then
  #  puts '------- CONDENSING to latest -------'
  #  puts "ALL:\n#{all_revs}"
  #  puts "LATEST:\n#{latest_revs}"
  # end

  latest_revs
end

def get_pr_review_data(pr)
  reviews =
    get_pending_reviews(pr.review_requests.nodes) +
    get_reviews(pr.reviews.nodes)
  reviews
end

branch_data = branches.map do |branch|
  branch.extend(H)
  {
    name: branch.name,
    committer: branch.target.committer.email,
    last_commit: get_yyyymmdd(branch.target.committed_date),
    last_commit_age: age(branch.target.committed_date),
    status: branch.target.status ? branch.target.status.state : nil
  }
end

pr_data = branches.
          map { |b| b.associated_pull_requests.nodes }.
          select { |prs| prs.size() == 1 }.
          map { |prs| prs[0] }.
          map do |pr|
  pr.extend(H)
  {
    branch: pr.head_ref_name,
    number: pr.number,
    url: pr.url,
    created: pr.created_at,
    age: age(pr.created_at),
    mergeable: pr.mergeable == 'MERGEABLE',
    reviews: get_pr_review_data(pr)
  }
end
  
puts branch_data.inspect
puts pr_data.inspect
