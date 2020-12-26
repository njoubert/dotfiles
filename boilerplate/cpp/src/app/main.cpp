/*
 * Copyright (C) 2019 Niels Joubert
 * Contact: Niels Joubert <njoubert@gmail.com>
 *
 * This source is subject to the license found in the file 'LICENSE' which must
 * be be distributed together with this source. All other rights reserved.
 *
 * THIS CODE AND INFORMATION IS PROVIDED "AS IS" WITHOUT WARRANTY OF ANY KIND,
 * EITHER EXPRESSED OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE IMPLIED
 * WARRANTIES OF MERCHANTABILITY AND/OR FITNESS FOR A PARTICULAR PURPOSE.
 */
#include <cstring>
#include <cstdio>

namespace App {
	
void init() {
	fprintf(stdout, "Welcome to the App namespace in your Main file.\n");
}

} /* namespace App */

int main(int argc, char *argv[]) {
	
	App::init();

	return 0;
}
