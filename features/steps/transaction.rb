#
# Filename: features/support/transaction.rb
#
# This is part of the Alchemy configuration database. For more
# information, visit our home on the web at
#
#     https://github.com/jamespharaoh/alchemy
#
# Copyright 2011 James Pharaoh
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

Before do
	@transaction_token = gen_token
	@revisions = Hash.new { gen_token }
end

Given /^the following rows:$/ do |table|
	step "I begin a transaction"
	step "I send an update message containing:", table
	step "I receive an update-ok message"
	step "I commit the transaction"
end

When /^I begin a(?:nother)? transaction$/ do
	step "I send a begin message"
	step "I receive a begin-ok message"
end

When /^I commit the transaction$/ do
	step "I send a commit message"
	step "I receive a commit-ok message"
end

When /^I rollback the transaction$/ do
	step "I send a rollback message"
	step "I receive a rollback-ok message"
end

When /^I begin and commit a transaction$/ do
	step "I begin a transaction"
	step "I commit the transaction"
end

When /^I begin and rollback a transaction$/ do
	step "I begin a transaction"
	step "I rollback the transaction"
end

When /^I send a(?:nother)? begin message$/ do
	server_call :default, "begin"
end

When /^I send a(?:nother)? commit message$/ do
	server_call :default, "commit", @transaction_token
end

When /^I send a(?:nother)? rollback message$/ do
	server_call :default, "rollback", @transaction_token
end

When /^I perform the following updates:$/ do |table|
	step "I send an update message containing:", table
	step "I receive an update-ok message"
end

When /^I send an update message$/ do
	raw = [ [ "key", "rev", "value" ] ]
	table = Cucumber::Ast::Table.new raw
	step "I send an update message containing:", table
end

When /^I send an update message containing:$/ do |table|
	updates = table.hashes.map { |hash| [
		parse_array(hash["key"]),
		hash["in"] && ! hash["in"].empty? ?
			@revisions[hash["in"]] : nil,
		parse_object(hash["value"]),
	] }
	server_call :default, "update", @transaction_token, updates
	@update_outs = table.hashes.map { |hash| hash["out"] or nil }
end

Then /^I receive a begin\-ok message$/ do
	name, *args = server_response
	name.should == "begin-ok"
	args.size.should == 1
	args [0].should match /^[a-z]{10}$/
	@transaction_token = args [0]
end

Then /^I receive a rollback\-ok message$/ do
	name, *args = server_response
	name.should == "rollback-ok"
	args.size.should == 0
end

Then /^I receive a commit\-ok message$/ do
	name, *args = server_response
	name.should == "commit-ok"
	args.size.should == 0
end

Then /^I receive an update\-ok message$/ do
	name, *args = server_response
	name.should == "update-ok"
	args.size.should == 1
	revs = args[0]
	revs.size.should == @update_outs.size
	revs.each do |rev| rev.should match /^[a-z]{10}$/ end
	@update_outs.each_with_index do |out, i|
		next unless out
		@revisions[out] = revs[i]
	end
end

Then /^I receive a transaction\-token\-invalid message$/ do
	name, *args = server_response
	name.should == "transaction-token-invalid"
	args.size.should == 0
end

Then /^I receive an update\-error message$/ do
	name, *args = server_response
	name.should == "update-error"
	args.size.should == 0
end

Then /^the following rows should exist:$/ do |table|
	keys = table.hashes.map { |hash| parse_array hash["key"] }
	server_call :default, "fetch", @transaction_token, keys
	name, *args = server_response
	name.should == "fetch-ok"
	args.size.should == 1
	rows = args[0]
	values = rows.map { |row| row[1] }
	expect = table.hashes.map { |hash| parse_object hash["value"] }
	values.should == expect
end
