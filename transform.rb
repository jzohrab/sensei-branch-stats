require 'date'


module BranchStatistics

  # Transforms data
  class Transform

    class << self  # All methods are public class (static) methods

      # Transform the data returned by data sources.
      def transform(graphql_branches, commit_stats)
        branch_data = graphql_branches.map do |branch|
          branch_data = {
            name: branch.name,
            committer: branch.target.committer.email,
            last_commit: get_yyyymmdd(branch.target.committed_date),
            last_commit_age: age(branch.target.committed_date),
            status: branch.target.status ? branch.target.status.state : nil
          }
          
          pr_data = {}
          if (branch.associated_pull_requests.nodes.size() == 1) then
            pr = branch.associated_pull_requests.nodes[0]
            pr_data = {
              branch: pr.head_ref_name,
              number: pr.number,
              title: pr.title,
              url: pr.url,
              created: get_yyyymmdd(pr.created_at),
              age: age(pr.created_at),
              mergeable: pr.mergeable == 'MERGEABLE',
              reviews: get_pr_review_data(pr)
            }
          end
          
          {
            branch: branch_data,
            pr: pr_data,
            commits: commit_stats[branch.name]
          }
          
        end

        return branch_data
      end


      ############################
      # Helpers

      def age(s)
        d = Date.strptime(get_yyyymmdd(s), "%Y-%m-%d")
        age = (Date::today - d).to_i
      end

      def get_yyyymmdd(s)
        s.match(/(\d{4}-\d{2}-\d{2})/)[1]
      end

      # Review dates are stored as "2018-06-12T13:43:35Z",
      # need date and time to determine the last review.
      def get_yyyymmdd_hhnnss(s)
        return s.gsub('T', ' ').gsub('Z', '')
      end
      
      def get_pending_reviews(requests)
        # puts "REQ: #{requests}"
        requests.map { |r| r.requested_reviewer }.map do |r|
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
        all_revs = reviews.map do |r|
          {
            status: r.state,
            reviewer: r.author.login,
            date: get_yyyymmdd_hhnnss(r.updated_at),
            age: age(r.updated_at)
          }
        end
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
      
    end  # class << self

  end  # class Transform

end   # module
