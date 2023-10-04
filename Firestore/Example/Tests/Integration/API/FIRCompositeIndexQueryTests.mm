/*
 * Copyright 2023 Google LLC
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

#import <FirebaseFirestore/FirebaseFirestore.h>
#import "Firestore/Example/Tests/Util/FSTIntegrationTestCase.h"

#include "Firestore/core/src/util/autoid.h"

using firebase::firestore::util::CreateAutoId;

NS_ASSUME_NONNULL_BEGIN

static NSString *const TEST_ID_FIELD = @"testId";
static NSString *const TTL_FIELD = @"expireAt";
static NSString *const COMPOSITE_INDEX_TEST_COLLECTION = @"composite-index-test-collection";

/**
 * This FIRCompositeIndexQueryTests class is designed to facilitate integration
 * testing of Firestore queries that require composite indexes within a
 * controlled testing environment.
 *
 * Key Features:
 * - Runs tests against the dedicated test collection with predefined composite
 *   indexes.
 * - Automatically associates a test ID with documents for data isolation.
 * - Utilizes TTL policy for automatic test data cleanup.
 * - Constructs Firestore queries with test ID filters.
 */
@interface FIRCompositeIndexQueryTests : FSTIntegrationTestCase
// Creates a new unique identifier for each test case to ensure data isolation.
@property(nonatomic, strong) NSString *testId;
@end

@implementation FIRCompositeIndexQueryTests

- (void)setUp {
  [super setUp];
  _testId = [NSString stringWithFormat:@"test-id-%s", CreateAutoId().c_str()];
}

#pragma mark - Test Helpers

// Return reference to the static test collection: composite-index-test-collection
- (FIRCollectionReference *)testCollectionRef {
  return [self.db collectionWithPath:COMPOSITE_INDEX_TEST_COLLECTION];
}

// Runs a test with specified documents in the COMPOSITE_INDEX_TEST_COLLECTION.
- (FIRCollectionReference *)withTestDocs:
    (NSDictionary<NSString *, NSDictionary<NSString *, id> *> *)docs {
  FIRCollectionReference *writer = [self testCollectionRef];
  // Use a different instance to write the documents
  [self writeAllDocuments:[self prepareTestDocuments:docs]
             toCollection:[self.firestore collectionWithPath:writer.path]];
  return self.testCollectionRef;
}

// Hash the document key with testId.
- (NSString *)toHashedId:(NSString *)docId {
  return [NSString stringWithFormat:@"%@-%@", docId, self.testId];
}

- (NSArray<NSString *> *)toHashedIds:(NSArray<NSString *> *)docs {
  NSMutableArray<NSString *> *hashedIds = [NSMutableArray arrayWithCapacity:docs.count];
  for (NSString *doc in docs) {
    [hashedIds addObject:[self toHashedId:doc]];
  }
  return hashedIds;
}

// Adds test-specific fields to a document, including the testId and expiration date.
- (NSDictionary<NSString *, id> *)addTestSpecificFieldsToDoc:(NSDictionary<NSString *, id> *)doc {
  NSMutableDictionary<NSString *, id> *updatedDoc = [doc mutableCopy];
  updatedDoc[TEST_ID_FIELD] = self.testId;
  int64_t expirationTime =
      [[FIRTimestamp timestamp] seconds] + 24 * 60 * 60;  // Expire test data after 24 hours
  updatedDoc[TTL_FIELD] = [FIRTimestamp timestampWithSeconds:expirationTime nanoseconds:0];
  return [updatedDoc copy];
}

// Remove test-specific fields from a Firestore document.
- (NSDictionary<NSString *, id> *)removeTestSpecificFieldsFromDoc:
    (NSDictionary<NSString *, id> *)doc {
  NSMutableDictionary<NSString *, id> *mutableDoc = [doc mutableCopy];
  [mutableDoc removeObjectForKey:TEST_ID_FIELD];
  [mutableDoc removeObjectForKey:TTL_FIELD];

  // Update the document with the modified data.
  return [mutableDoc copy];
}

// Helper method to hash document keys and add test-specific fields for the provided documents.
- (NSDictionary<NSString *, NSDictionary<NSString *, id> *> *)prepareTestDocuments:
    (NSDictionary<NSString *, NSDictionary<NSString *, id> *> *)docs {
  NSMutableDictionary<NSString *, NSDictionary<NSString *, id> *> *result =
      [NSMutableDictionary dictionaryWithCapacity:docs.count];
  for (NSString *key in docs.allKeys) {
    NSDictionary<NSString *, id> *doc = docs[key];
    NSDictionary<NSString *, id> *updatedDoc = [self addTestSpecificFieldsToDoc:doc];
    result[[self toHashedId:key]] = updatedDoc;
  }
  return [result copy];
}

// Asserts that the result of running the query while online (against the backend/emulator) is
// the same as running it while offline. The expected document Ids are hashed to match the
// actual document IDs created by the test helper.
- (void)assertOnlineAndOfflineResultsMatch:(FIRQuery *)query
                              expectedDocs:(NSArray<NSString *> *)expectedDocs {
  [self checkOnlineAndOfflineQuery:query matchesResult:[self toHashedIds:expectedDocs]];
}

// Adds a filter on test id for a query.
- (FIRQuery *)query:(FIRQuery *)query_ {
  return [query_ queryWhereField:TEST_ID_FIELD isEqualTo:self.testId];
}

// Get a document reference from a document key.
- (FIRDocumentReference *)getDocRef:(FIRCollectionReference *)coll docId:(NSString *)docId {
  NSString *hashedDocId = [self toHashedId:docId];
  return [coll documentWithPath:hashedDocId];
}

// Adds a document to a Firestore collection with test-specific fields.
- (FIRDocumentReference *)addDoc:(FIRCollectionReference *)collection
                            data:(NSDictionary<NSString *, id> *)data {
  NSDictionary<NSString *, id> *updatedData = [self addTestSpecificFieldsToDoc:data];
  return [self addDocumentRef:collection data:updatedData];
}

// Sets a document in Firestore with test-specific fields.
- (void)setDoc:(FIRDocumentReference *)document data:(NSDictionary<NSString *, id> *)data {
  NSDictionary<NSString *, id> *updatedData = [self addTestSpecificFieldsToDoc:data];
  return [self mergeDocumentRef:document data:updatedData];
}

// Update a document in Firestore with test-specific fields.
- (void)updateDoc:(FIRDocumentReference *)document data:(NSDictionary<NSString *, id> *)data {
  NSDictionary<NSString *, id> *updatedData = [self addTestSpecificFieldsToDoc:data];
  [self updateDocumentRef:document data:updatedData];
}

// Delete a document from Firestore.
- (void)deleteDoc:(FIRDocumentReference *)document {
  [self deleteDocumentRef:document];
}

// Retrieve a single document from Firestore with test-specific fields removed.
// TODO(composite-index-testing) Return sanitized DocumentSnapshot instead of its data.
- (NSDictionary<NSString *, id> *)getDocSnapshotData:(FIRDocumentReference *)document {
  FIRDocumentSnapshot *docSnapshot = [self readDocumentForRef:document];
  return [self removeTestSpecificFieldsFromDoc:docSnapshot.data];
}

// Retrieve multiple documents from Firestore with test-specific fields removed.
// TODO(composite-index-testing) Return sanitized QuerySnapshot instead of its data.
- (NSArray<NSDictionary<NSString *, id> *> *)getQuerySnapshotData:(FIRQuery *)query {
  FIRQuerySnapshot *querySnapshot = [self readDocumentSetForRef:query];
  NSMutableArray<NSDictionary<NSString *, id> *> *result = [NSMutableArray array];
  for (FIRDocumentSnapshot *doc in querySnapshot.documents) {
    [result addObject:[self removeTestSpecificFieldsFromDoc:doc.data]];
  }
  return result;
}

#pragma mark - Test Cases

/*
 * Guidance for Creating Tests:
 * ----------------------------
 * When creating tests that require composite indexes, it is recommended to utilize the
 * test helpers in this class. This utility class provides methods for creating
 * and setting test documents and running queries with ease, ensuring proper data
 * isolation and query construction.
 *
 * Please remember to update the main index configuration file (firestore_index_config.tf)
 * with any new composite indexes needed for the tests. This ensures synchronization with
 * other testing environments, including CI. You can generate the required index link by
 * clicking on the Firebase console link in the error message while running tests locally.
 */

- (void)testOrQueriesWithCompositeIndexes {
  FIRCollectionReference *collRef = [self withTestDocs:@{
    @"doc1" : @{@"a" : @1, @"b" : @0},
    @"doc2" : @{@"a" : @2, @"b" : @1},
    @"doc3" : @{@"a" : @3, @"b" : @2},
    @"doc4" : @{@"a" : @1, @"b" : @3},
    @"doc5" : @{@"a" : @1, @"b" : @1}
  }];
  // with one inequality: a>2 || b==1.
  FIRFilter *filter1 = [FIRFilter orFilterWithFilters:@[
    [FIRFilter filterWhereField:@"a" isGreaterThan:@2], [FIRFilter filterWhereField:@"b"
                                                                          isEqualTo:@1]
  ]];
  [self assertOnlineAndOfflineResultsMatch:[self query:[collRef queryWhereFilter:filter1]]
                              expectedDocs:@[ @"doc5", @"doc2", @"doc3" ]];

  // Test with limits (implicit order by ASC): (a==1) || (b > 0) LIMIT 2
  FIRFilter *filter2 = [FIRFilter orFilterWithFilters:@[
    [FIRFilter filterWhereField:@"a" isEqualTo:@1], [FIRFilter filterWhereField:@"b"
                                                                  isGreaterThan:@0]
  ]];
  [self assertOnlineAndOfflineResultsMatch:[[self query:[collRef queryWhereFilter:filter2]]
                                               queryLimitedTo:2]
                              expectedDocs:@[ @"doc1", @"doc2" ]];

  // Test with limits (explicit order by): (a==1) || (b > 0) LIMIT_TO_LAST 2
  // Note: The public query API does not allow implicit ordering when limitToLast is used.
  FIRFilter *filter3 = [FIRFilter orFilterWithFilters:@[
    [FIRFilter filterWhereField:@"a" isEqualTo:@1], [FIRFilter filterWhereField:@"b"
                                                                  isGreaterThan:@0]
  ]];
  [self assertOnlineAndOfflineResultsMatch:[[[self query:[collRef queryWhereFilter:filter3]]
                                               queryLimitedToLast:2] queryOrderedByField:@"b"]
                              expectedDocs:@[ @"doc3", @"doc4" ]];

  // Test with limits (explicit order by ASC): (a==2) || (b == 1) ORDER BY a LIMIT 1
  FIRFilter *filter4 = [FIRFilter orFilterWithFilters:@[
    [FIRFilter filterWhereField:@"a" isEqualTo:@2], [FIRFilter filterWhereField:@"b" isEqualTo:@1]
  ]];
  [self assertOnlineAndOfflineResultsMatch:[[[self query:[collRef queryWhereFilter:filter4]]
                                               queryLimitedTo:1] queryOrderedByField:@"a"]
                              expectedDocs:@[ @"doc5" ]];

  // Test with limits (explicit order by DESC): (a==2) || (b == 1) ORDER BY a LIMIT_TO_LAST 1
  FIRFilter *filter5 = [FIRFilter orFilterWithFilters:@[
    [FIRFilter filterWhereField:@"a" isEqualTo:@2], [FIRFilter filterWhereField:@"b" isEqualTo:@1]
  ]];
  [self assertOnlineAndOfflineResultsMatch:[[[self query:[collRef queryWhereFilter:filter5]]
                                               queryLimitedToLast:1] queryOrderedByField:@"a"]
                              expectedDocs:@[ @"doc2" ]];
}

@end

NS_ASSUME_NONNULL_END
