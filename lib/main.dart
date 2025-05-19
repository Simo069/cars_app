import 'package:flutter/material.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'dart:async';

void main() async {
  // Ensure initialized
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize database
  final database = await openDatabase(
    join(await getDatabasesPath(), 'car_rental_database.db'),
    onCreate: (db, version) async {
      // Create Cars table
      await db.execute(
        'CREATE TABLE cars(id INTEGER PRIMARY KEY, brand TEXT, model TEXT, image TEXT, rating REAL, available BOOLEAN, pricePerDay REAL)',
      );
      
      // Insert initial data
      await db.insert('cars', {'brand': 'Tesla', 'model': 'Model 3', 'image': 'images/tesla_model3.png', 'rating': 4.8, 'available': 1, 'pricePerDay': 85.0});
      await db.insert('cars', {'brand': 'BMW', 'model': 'M4', 'image': 'images/bmw_m4.png', 'rating': 4.9, 'available': 1, 'pricePerDay': 105.0});
      await db.insert('cars', {'brand': 'Tesla', 'model': 'Model Y', 'image': 'images/tesla_modely.png', 'rating': 4.7, 'available': 1, 'pricePerDay': 95.0});
      await db.insert('cars', {'brand': 'Mercedes', 'model': 'E-Class', 'image': 'images/mercedes_eclass.png', 'rating': 4.9, 'available': 1, 'pricePerDay': 110.0});
    },
    version: 1,
  );
  
  runApp(CarRentalApp(database: database));
}

// Car Model class
class Car {
  final int? id;
  final String brand;
  final String model;
  final String image;
  final double rating;
  final bool available;
  final double pricePerDay;

  Car({
    this.id,
    required this.brand,
    required this.model,
    required this.image,
    required this.rating,
    required this.available,
    required this.pricePerDay,
  });

  // Convert Car to Map
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'brand': brand,
      'model': model,
      'image': image,
      'rating': rating,
      'available': available ? 1 : 0,
      'pricePerDay': pricePerDay,
    };
  }

  // Create Car from Map
  factory Car.fromMap(Map<String, dynamic> map) {
    return Car(
      id: map['id'],
      brand: map['brand'],
      model: map['model'],
      image: map['image'],
      rating: map['rating'],
      available: map['available'] == 1,
      pricePerDay: map['pricePerDay'],
    );
  }
}

// Database Helper class
class CarDatabase {
  final Database database;

  CarDatabase(this.database);

  // Get all cars
  Future<List<Car>> getCars() async {
    final List<Map<String, dynamic>> maps = await database.query('cars');
    return List.generate(maps.length, (i) => Car.fromMap(maps[i]));
  }

  // Get cars by brand
  Future<List<Car>> getCarsByBrand(String brand) async {
    final List<Map<String, dynamic>> maps = await database.query(
      'cars',
      where: 'brand = ?',
      whereArgs: [brand],
    );
    return List.generate(maps.length, (i) => Car.fromMap(maps[i]));
  }

  // Update car availability
  Future<void> updateCarAvailability(int id, bool available) async {
    await database.update(
      'cars',
      {'available': available ? 1 : 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}

// Main App Widget
class CarRentalApp extends StatelessWidget {
  final Database database;

  const CarRentalApp({Key? key, required this.database}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Car Rental App',
      theme: ThemeData(
        primarySwatch: Colors.red,
        scaffoldBackgroundColor: Colors.white,
        fontFamily: 'Roboto',
      ),
      home: HomeScreen(carDatabase: CarDatabase(database)),
    );
  }
}

// Home Screen
class HomeScreen extends StatefulWidget {
  final CarDatabase carDatabase;

  const HomeScreen({Key? key, required this.carDatabase}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _selectedCategory = 'All';
  List<Car> _cars = [];
  List<Car> _filteredCars = [];
  bool _isLoading = true;
  TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadCars();
    _searchController.addListener(_filterCarsBySearch);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadCars() async {
    setState(() {
      _isLoading = true;
    });
    
    final cars = await widget.carDatabase.getCars();
    
    setState(() {
      _cars = cars;
      _filteredCars = cars;
      _isLoading = false;
    });
  }

  void _filterCarsByCategory(String category) {
    setState(() {
      _selectedCategory = category;
      if (category == 'All') {
        _filteredCars = _cars;
      } else {
        _filteredCars = _cars.where((car) => car.brand == category).toList();
      }
    });
  }

  void _filterCarsBySearch() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        // Apply only category filter
        _filterCarsByCategory(_selectedCategory);
      } else {
        // Apply both category and search filters
        if (_selectedCategory == 'All') {
          _filteredCars = _cars.where((car) => 
            car.brand.toLowerCase().contains(query) || 
            car.model.toLowerCase().contains(query)
          ).toList();
        } else {
          _filteredCars = _cars.where((car) => 
            car.brand == _selectedCategory && 
            (car.brand.toLowerCase().contains(query) || car.model.toLowerCase().contains(query))
          ).toList();
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 16),
                    _buildHeader(),
                    const SizedBox(height: 20),
                    _buildSearchBar(),
                    const SizedBox(height: 24),
                    _buildCategories(),
                    const SizedBox(height: 24),
                    _buildFeaturedCarsSection(),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text(
          'Hello, John',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        IconButton(
          icon: const Icon(Icons.notifications_outlined),
          onPressed: () {
            // Handle notification press
          },
        ),
      ],
    );
  }

  Widget _buildSearchBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          const Icon(Icons.search, color: Colors.grey),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                hintText: 'Search for your dream car',
                border: InputBorder.none,
                hintStyle: TextStyle(color: Colors.grey),
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.tune, color: Colors.red),
          ),
        ],
      ),
    );
  }

  Widget _buildCategories() {
    // Get unique brands for categories
    final brands = ['All', ..._cars.map((car) => car.brand).toSet().toList()];
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Categories',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: brands.map((brand) => _buildCategoryItem(brand)).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryItem(String text) {
    final isSelected = _selectedCategory == text;
    
    return GestureDetector(
      onTap: () => _filterCarsByCategory(text),
      child: Container(
        margin: const EdgeInsets.only(right: 12),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? Colors.red : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.grey.shade700,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildFeaturedCarsSection() {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Featured Cars',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              TextButton(
                onPressed: () {
                  // View all cars
                },
                child: const Text(
                  'View All',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Expanded(
          //   child: _filteredCars.isEmpty
          //       ? const Center(child: Text('No cars found'))
          //       : 
          //       GridView.builder(
                  
          //           gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          //             crossAxisCount: 2,
          //             crossAxisSpacing: 16,
          //             mainAxisSpacing: 16,
          //             childAspectRatio: 0.75,
          //           ),
          //           itemCount: _filteredCars.length,
          //           itemBuilder: (context, index) {
          //             final car = _filteredCars[index];
          //             return _buildCarCard( context,car);
          //           },
          //         ),
                

          // ),
          Expanded(
            child: _filteredCars.isEmpty
                ? const Center(child: Text('No cars found'))
                : ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _filteredCars.length,
                    itemBuilder: (context, index) {
                      final car = _filteredCars[index];
                      return Container(
                        
                        width: MediaQuery.of(context).size.width * 0.7,
                        margin: const EdgeInsets.only(right: 16),
                        child: _buildCarCard(context,car),
                      );
                    },
                  ),
          ),

          
        ],
      ),
    );
  }

  Widget _buildCarCard(BuildContext context,Car car) {
    return GestureDetector(
      onTap: () {
        // Navigate to car details page
        Navigator.push(
          context, 
          MaterialPageRoute(
            builder: (context) => CarDetailScreen(car: car, carDatabase: widget.carDatabase),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.shade200,
              blurRadius: 5,
              spreadRadius: 1,
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
              child: AspectRatio(
                aspectRatio: 16 / 10,
                child: Container(
                  color: Colors.grey.shade300,
                  child: Image.asset(
                    car.image,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => const Center(
                      child: Text(
                        'Image non disponible',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    car.brand,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    car.model,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(
                        Icons.star,
                        color: Colors.amber,
                        size: 16,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        car.rating.toString(),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '\$${car.pricePerDay.toStringAsFixed(0)}/day',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.red,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Car Detail Screen
class CarDetailScreen extends StatefulWidget {
  final Car car;
  final CarDatabase carDatabase;

  const CarDetailScreen({
    Key? key,
    required this.car,
    required this.carDatabase,
  }) : super(key: key);

  @override
  State<CarDetailScreen> createState() => _CarDetailScreenState();
}

class _CarDetailScreenState extends State<CarDetailScreen> {
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now().add(const Duration(days: 1));
  int _rentalDays = 1;
  
  @override
  void initState() {
    super.initState();
    _calculateRentalDays();
  }
  
  void _calculateRentalDays() {
    setState(() {
      _rentalDays = _endDate.difference(_startDate).inDays;
      if (_rentalDays < 1) _rentalDays = 1;
    });
  }

  Future<void> _selectStartDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null && picked != _startDate) {
      setState(() {
        _startDate = picked;
        // Make sure end date is not before start date
        if (_endDate.isBefore(_startDate)) {
          _endDate = _startDate.add(const Duration(days: 1));
        }
        _calculateRentalDays();
      });
    }
  }

  Future<void> _selectEndDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _endDate.isAfter(_startDate) ? _endDate : _startDate.add(const Duration(days: 1)),
      firstDate: _startDate.add(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null && picked != _endDate) {
      setState(() {
        _endDate = picked;
        _calculateRentalDays();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.car.brand} ${widget.car.model}'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Car Image
                  SizedBox(
                    height: 250,
                    width: double.infinity,
                    child: Image.asset(
                      widget.car.image,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Center(
                        child: Icon(
                          Icons.directions_car,
                          size: 100,
                          color: Colors.grey.shade400,
                        ),
                      ),
                    ),
                  ),
                  
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Car Details
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '${widget.car.brand} ${widget.car.model}',
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Row(
                              children: [
                                const Icon(Icons.star, color: Colors.amber),
                                const SizedBox(width: 4),
                                Text(
                                  widget.car.rating.toString(),
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        
                        const SizedBox(height: 8),
                        Text(
                          '\$${widget.car.pricePerDay.toStringAsFixed(0)} per day',
                          style: const TextStyle(
                            fontSize: 18,
                            color: Colors.red,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        
                        const SizedBox(height: 24),
                        const Text(
                          'Select Rental Dates',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: GestureDetector(
                                onTap: () => _selectStartDate(context),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                                  decoration: BoxDecoration(
                                    border: Border.all(color: Colors.grey.shade300),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Start Date',
                                        style: TextStyle(
                                          color: Colors.grey.shade600,
                                          fontSize: 12,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '${_startDate.day}/${_startDate.month}/${_startDate.year}',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: GestureDetector(
                                onTap: () => _selectEndDate(context),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                                  decoration: BoxDecoration(
                                    border: Border.all(color: Colors.grey.shade300),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'End Date',
                                        style: TextStyle(
                                          color: Colors.grey.shade600,
                                          fontSize: 12,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '${_endDate.day}/${_endDate.month}/${_endDate.year}',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        
                        const SizedBox(height: 24),
                        const Text(
                          'Car Features',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _buildFeatureItem(Icons.speed, 'Auto'),
                            _buildFeatureItem(Icons.ac_unit, 'A/C'),
                            _buildFeatureItem(Icons.local_gas_station, 'Petrol'),
                            _buildFeatureItem(Icons.airline_seat_recline_normal, '5 Seats'),
                          ],
                        ),
                        
                        const SizedBox(height: 24),
                        const Text(
                          'Description',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        
                        const SizedBox(height: 8),
                        Text(
                          'Experience the luxury and performance of the ${widget.car.brand} ${widget.car.model}. This premium vehicle offers comfort, style, and advanced technology features that make every journey memorable.',
                          style: TextStyle(
                            color: Colors.grey.shade700,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // Bottom Bar
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.shade300,
                  blurRadius: 10,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Total Price',
                        style: TextStyle(
                          color: Colors.grey,
                        ),
                      ),
                      Text(
                        '\$${(widget.car.pricePerDay * _rentalDays).toStringAsFixed(0)}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 20,
                        ),
                      ),
                      Text(
                        'for $_rentalDays days',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      // Process rental
                      _showRentalConfirmationDialog(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text(
                      'Rent Now',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureItem(IconData icon, String text) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: Colors.grey.shade700),
        ),
        const SizedBox(height: 8),
        Text(
          text,
          style: TextStyle(
            color: Colors.grey.shade700,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  void _showRentalConfirmationDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Car Rental'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${widget.car.brand} ${widget.car.model}'),
            const SizedBox(height: 8),
            Text('From: ${_startDate.day}/${_startDate.month}/${_startDate.year}'),
            Text('To: ${_endDate.day}/${_endDate.month}/${_endDate.year}'),
            const SizedBox(height: 8),
            Text('Total: \$${(widget.car.pricePerDay * _rentalDays).toStringAsFixed(0)}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              // Update car availability in the database
              await widget.carDatabase.updateCarAvailability(widget.car.id!, false);
              
              // Close dialog and navigate back to home
              if (mounted) {
                Navigator.pop(context); // Close dialog
                Navigator.pop(context); // Return to home screen
                
                // Show success message
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('${widget.car.brand} ${widget.car.model} rented successfully!'),
                    backgroundColor: Colors.green,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }
}