# make sure to install pymongo library
# pip install "pymongo[srv]"

from pymongo import MongoClient

# MongoDB connection string
conn_string = "mongodb+srv://padamdamai:helloworld@mongodb-dev.117lpjo.mongodb.net/"
               

# Connect to MongoDB
client = MongoClient(conn_string)

# Select the database
db = client['airbnb']

# Select the collection
collection = db['reviews']

# Insert a document
# insert_result = collection.insert_one({'name': 'Padam damai','country': 'Nepal', 'age': 21})
# print(f"Document inserted with id: {insert_result.inserted_id}")

# Query the collection
# find_query = {'property_type' : 'Apartment', 'room_type': 'Private room'}
# find_query = { '$or' : [ {'property_type' : 'House'} , {'property_type' : 'Apartment'} ] }
# find_query = { 'room_type': 'Private room', 
#                '$or' : [ {'property_type' : 'House'} , {'property_type' : 'Apartment'} ] 
#             }
# find_query = { 'accommodates': { '$gt' : 2} }

# count_results = collection.count_documents(find_query)
# print("Total Documents Found : ",count_results)
# print("===========================")

# # Print documents fetched from find query
# find_results = collection.find(find_query)
# for doc in find_results:
#     print(doc)
#     break

# grp1 = [
#     {
#         "$group": {
#             "_id": "$address.country",  # Field to group by
#             "avg_price": {"$avg": "$price"}  # Field to avg
#         }
#     },
#     {
#         "$project": {
#             "country": "$_id",
#             "country_wise_avg_price": {"$toDouble": "$avg_price"},
#             "_id": 0

#         }
#     }
# ]

# grp1 = [
#     {
#         "$group": {
#             "_id": "$address.country",  # Field to group by
#             "avg_price": {"$avg": "$price"}  # Field to avg
#         }
#     }
# ]

# grp1 = [
#     {
#         "$group": {
#             "_id": {
#                 "country": "$address.country",
#                 "city": "$address.suburb"
#             },
#             "avg_price": {"$avg": "$price"}
#         }
#     }
# ]

# grp1 = [
#     {
#         "$group": {
#             "_id": {
#                 "country": "$address.country",
#                 "city": "$address.suburb"
#             },
#             "avg_price": {"$avg": "$price"}
#         }
#     },
#     {
#         "$project": {
#             "country": "$_id.country",
#             "city": "$_id.city",
#             "city_wise_avg_price": {"$toDouble": "$avg_price"},
#             "_id": 0
#         }
#     }
# ]


results = collection.aggregate(grp1)
for result in results:
    print(result)


# Close the connection
client.close()