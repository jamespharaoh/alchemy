#
# Filename: features/support/env.rb
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

def gen_token
	return (0...10).to_a.map { (?a..?z).to_a.sample }.join
end
