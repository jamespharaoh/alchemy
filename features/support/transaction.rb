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

Given /^that I have begun a transaction$/ do
	server_call :default, "begin"
	name, *args = server_response
	case [ name, args.size ]

		when [ "begin-ok", 1 ]
			@transaction_token = args [0]

		else
			raise "Error"
	end
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

Then /^I should receive a begin\-ok message with a valid transaction id$/ do
	name, *args = server_response
	name.should == "begin-ok"
	args.size.should == 1
	args [0].should match /^[a-z]{10}$/
end

Then /^I should receive a rollback\-ok message$/ do
	name, *args = server_response
	name.should == "rollback-ok"
	args.size.should == 0
end

Then /^I should receive a rollback\-error message$/ do
	name, *args = server_response
	name.should == "rollback-error"
	args.size.should == 0
end

Then /^I should receive a commit\-ok message$/ do
	name, *args = server_response
	name.should == "commit-ok"
	args.size.should == 0
end

Then /^I should receive a commit\-error message$/ do
	name, *args = server_response
	name.should == "commit-error"
	args.size.should == 0
end

