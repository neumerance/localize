# find all revisions which are still open to bids, and who's bidding close time has expired
bidding_closed_revisions = Revision.where('(open_to_bids= ?) AND (bidding_close_time < ?)', 1, Time.now)

bidding_closed_revisions.each do |revision|
  # xxxx - notify the client that the revision's bidding is done
  # TODO

  # close that revision
  revision.open_to_bids = 0
  revision.save!
end

# find all bids that are in-progress and need to have been completed by now
expired_bids = Bid.where('(status= ?) AND (expiration_time < ?) AND (amount > 0)', BID_ACCEPTED, Time.now)

# xxxx - send notifications and allow clients to take action
