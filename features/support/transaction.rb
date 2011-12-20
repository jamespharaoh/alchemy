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
	server_start "alpha"
end

When /^I send a begin message$/ do
	pending # express the regexp above with the code you wish you had
end

When /^I send a commit message$/ do
	pending # express the regexp above with the code you wish you had
end

When /^I send another commit message$/ do
	pending # express the regexp above with the code you wish you had
end

When /^I send a rollback message$/ do
	pending # express the regexp above with the code you wish you had
end

When /^I Send a rollback message$/ do
	pending # express the regexp above with the code you wish you had
end

When /^I send another rollback message$/ do
	pending # express the regexp above with the code you wish you had
end

When /^I Send a commit message$/ do
	pending # express the regexp above with the code you wish you had
end

Then /^I should receive a begin\-ok message with a valid transaction id$/ do
	pending # express the regexp above with the code you wish you had
end

Then /^I should receive a rollback\-ok message$/ do
	pending # express the regexp above with the code you wish you had
end

Then /^I should receive a rollback\-error message$/ do
	pending # express the regexp above with the code you wish you had
end

Then /^I should receive a commit\-error message$/ do
	pending # express the regexp above with the code you wish you had
end

Then /^I should receive a commit\-ok message$/ do
	pending # express the regexp above with the code you wish you had
end


